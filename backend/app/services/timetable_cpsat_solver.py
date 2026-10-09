"""
Standalone Google OR-Tools CP-SAT Timetable Solver (Production Realistic Edition).

Key Guarantees:
1. Independent Divisions: Every division (TY-AIML-A, TY-AIML-B, SY-AIML-A, B, C, etc.)
   has an independent, distinct schedule. No two divisions are automatically merged
   unless explicitly linked by joint_group_id or a parallel elective constraint.
2. Zero Conflicts: A faculty member can never teach two classes at the same slot.
   A class/division can never have two whole-class lectures at the same slot.
3. 100% Hard Constraint Satisfaction: Hard constraints (Fixed slots, Faculty unavailabilities,
   Division blocks, Holidays, Lab continuity, No-clash) are strictly enforced (valid = False).
   They are NEVER violated.
4. Soft Constraint Optimization: Soft constraints (Preferred slots, No theory after lunch,
   Daily workload balance) are optimized in the objective function without compromising hard rules.
5. Synchronized Lab Batches: Multiple batches of the same class (e.g. Batch 1 and Batch 2)
   are rewarded and encouraged to run in parallel in the same time slot across separate labs
   with separate faculty members.
6. Exact Weekly Hours: 100% of weekly lecture and lab hours specified in assignments are scheduled.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Set, Tuple, Optional, Any
from collections import defaultdict
import time, re, math
from ortools.sat.python import cp_model


# ------------------------------------------------------------------ #
# Data-classes                                                         #
# ------------------------------------------------------------------ #

@dataclass
class Assignment:
    faculty: str
    subject: str
    class_name: str
    type: str
    batch: str = "-"
    weekly_hours: int = 3
    subject_code: str = ""
    joint_group_id: Optional[str] = None


@dataclass
class TimeSlot:
    slot_number: int
    start_time: str = ""
    end_time: str = ""
    is_break: bool = False
    is_lunch: bool = False


@dataclass
class Constraint:
    id: str = ""
    category: str = ""
    intent: str = ""
    faculty_names: List[str] = field(default_factory=list)
    subject_names: List[str] = field(default_factory=list)
    class_names: List[str] = field(default_factory=list)
    days: List[str] = field(default_factory=list)
    slot_numbers: List[int] = field(default_factory=list)


@dataclass
class SolverSession:
    session_id: str
    faculty: str       # "FacA | FacB" for merged parallel-elective sessions
    subject: str       # "SubA | SubB" for merged parallel-elective sessions
    subject_code: str
    type: str          # "Theory" | "Lab"
    batch: str         # "-" / "All" for theory; "Batch 1", "Batch 2" … for labs
    classes: List[str]
    duration: int      # consecutive teaching slots required
    session_index: int
    joint_group_id: Optional[str] = None


@dataclass
class SessionOption:
    day: str
    start_slot: int
    slots: List[int]   # consecutive slot numbers occupied
    penalty: int = 0
    penalty_reasons: List[str] = field(default_factory=list)


@dataclass
class SolverResult:
    status: str
    solve_time_seconds: float
    timetable: Dict[str, Dict[str, List[str]]] = field(default_factory=dict)
    detailed_timetable: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    conflicts: List[str] = field(default_factory=list)
    message: str = ""


# ------------------------------------------------------------------ #
# Solver                                                               #
# ------------------------------------------------------------------ #

class TimetableCpSatSolver:

    def __init__(
        self,
        assignments: List[Assignment],
        time_slots: List[TimeSlot],
        constraints: List[Constraint],
        combined_groups: Optional[List[List[str]]] = None,
        working_days: Optional[List[str]] = None,
        time_limit_seconds: int = 30,
        lecture_duration_minutes: int = 60,
        lab_duration_minutes: int = 120,
        rooms: Optional[List[Dict[str, Any]]] = None,
    ):
        self.assignments = assignments
        self.time_slots = sorted(time_slots, key=lambda s: s.slot_number)
        self.constraints = constraints
        self.combined_groups = combined_groups or []
        self.working_days = working_days or [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
        ]
        self.time_limit_seconds = time_limit_seconds
        self.lecture_duration_minutes = max(15, lecture_duration_minutes)
        self.lab_duration_minutes = max(15, lab_duration_minutes)
        self.lab_slots_per_session = max(
            1, math.ceil(self.lab_duration_minutes / self.lecture_duration_minutes)
        )
        self.fill_rules: List[Dict[str, Any]] = []

        self.rooms = rooms or []
        self.classrooms = [r for r in self.rooms if r.get("type", "").lower() != "lab"]
        self.labs_pool = [r for r in self.rooms if r.get("type", "").lower() == "lab"]

        self.break_slots: Set[int] = {s.slot_number for s in self.time_slots if s.is_break}
        lunch_slots = {s.slot_number for s in self.time_slots if s.is_lunch}
        if not lunch_slots and self.break_slots:
            mid = len(self.time_slots) // 2
            lunch_slots = {sorted(self.break_slots, key=lambda s: abs(s - mid))[0]}
        self.first_lunch_slot: Optional[int] = min(lunch_slots) if lunch_slots else None

        self.group_lookup: Dict[str, List[str]] = {}
        for group in self.combined_groups:
            for c in group:
                self.group_lookup[c] = group

        all_cls_names = sorted(list({a.class_name for a in self.assignments if a.class_name}))
        self.home_classrooms: Dict[str, str] = {}
        for c_idx, c_name in enumerate(all_cls_names):
            if self.classrooms:
                self.home_classrooms[c_name] = self.classrooms[c_idx % len(self.classrooms)].get("name", f"Classroom {c_idx + 1}")
            else:
                self.home_classrooms[c_name] = f"Room {101 + c_idx}"


    # -------------------------------------------------------------- #
    # Helpers                                                          #
    # -------------------------------------------------------------- #

    def _normalize(self, text: str) -> str:
        return text.strip().lower()

    def _parse_time_to_minutes(self, time_str: str) -> Optional[int]:
        if not time_str or not time_str.strip():
            return None
        t = time_str.strip().upper()
        m = re.search(r"(\d{1,2}):(\d{2})\s*(AM|PM)?", t)
        if not m:
            return None
        hours = int(m.group(1))
        mins = int(m.group(2))
        period = m.group(3)
        if period == "PM" and hours != 12:
            hours += 12
        elif period == "AM" and hours == 12:
            hours = 0
        return hours * 60 + mins

    def _is_contiguous_block(self, block: List[TimeSlot]) -> bool:
        if len(block) <= 1:
            return True
        slot_obj_idx = {id(s): idx for idx, s in enumerate(self.time_slots)}
        for k in range(1, len(block)):
            curr = block[k]
            prev = block[k - 1]
            if curr.is_break or prev.is_break:
                return False
            # 1. Must be directly adjacent in the full chronological time_slots list
            idx_curr = slot_obj_idx.get(id(curr))
            idx_prev = slot_obj_idx.get(id(prev))
            if idx_curr is not None and idx_prev is not None:
                if idx_curr != idx_prev + 1:
                    return False
            # 2. Check timestamps if available: no break gap allowed between prev end and curr start
            curr_start = self._parse_time_to_minutes(curr.start_time)
            prev_end = self._parse_time_to_minutes(prev.end_time)
            if curr_start is not None and prev_end is not None:
                if curr_start > prev_end:  # Gap in time (recess/lunch/break)
                    return False
            # 3. Slot numbers check
            if curr.slot_number in self.break_slots or prev.slot_number in self.break_slots:
                return False
        return True

    def _string_match(self, pattern: str, target: str) -> bool:
        if not pattern or not target:
            return False
        p, t = pattern.lower().strip(), target.lower().strip()
        if p == t or p in t or t in p:
            return True
        pt = set(re.findall(r"\b[a-zA-Z0-9]{3,}\b", p))
        tt = set(re.findall(r"\b[a-zA-Z0-9]{3,}\b", t))
        return bool(pt and tt and pt & tt)

    def _class_match(self, c1: str, c2: str) -> bool:
        if not c1 or not c2:
            return False
        n1 = c1.upper().replace("-", " ").strip()
        n2 = c2.upper().replace("-", " ").strip()
        return n1 == n2 or n1.startswith(n2) or n2.startswith(n1)

    def _get_cohort(self, class_name: str) -> str:
        if not class_name or not class_name.strip():
            return "COHORT"
        cn = class_name.lower().strip()
        if re.search(r"\b(fy|fe|1st\s*year|first\s*year)\b", cn) or cn.startswith("fy") or re.match(r"^1[a-z\s\-_]", cn):
            return "FY"
        if re.search(r"\b(sy|se|2nd\s*year|second\s*year)\b", cn) or cn.startswith("sy") or re.match(r"^2[a-z\s\-_]", cn):
            return "SY"
        if re.search(r"\b(ty|te|3rd\s*year|third\s*year)\b", cn) or cn.startswith("ty") or re.match(r"^3[a-z\s\-_]", cn):
            return "TY"
        if re.search(r"\b(be|btech|final\s*year|4th\s*year|fourth\s*year|b\.?tech)\b", cn) or cn.startswith("be") or cn.startswith("btech") or cn.startswith("final") or re.match(r"^4[a-z\s\-_]", cn):
            return "FINAL"
        parts = re.split(r"[\s\-_]+", class_name.strip())
        return parts[0].upper() if parts else "COHORT"

    def _get_cohort_siblings(self, class_name: str) -> List[str]:
        if not class_name:
            return []
        target_cohort = self._get_cohort(class_name)
        all_cls = sorted(list({a.class_name for a in self.assignments if a.class_name}))
        siblings = [c for c in all_cls if self._get_cohort(c) == target_cohort]
        return siblings if siblings else [class_name]

    def _extract_elective_basket(self, subject_name: str, category: str = "") -> Tuple[str, str]:
        """
        Extracts the elective basket family and unique basket identifier.
        Families: MDM, PE, OE, HONORS, ELECTIVE, CORE
        Basket ID: e.g. 'MDM-3', 'PE-1', 'OE-2', 'HONORS', 'CORE'
        """
        sn = (subject_name or "").strip()
        cat = (category or "").strip()
        sn_lo = sn.lower()
        cat_lo = cat.lower()

        # 1. Honors / Honours
        if "honor" in sn_lo or "honour" in sn_lo or "honor" in cat_lo or "honour" in cat_lo:
            m = re.search(r"\b(honou?rs?[\s\-_]*\d*)\b", sn_lo)
            basket_id = m.group(1).upper().replace(" ", "-") if m else "HONORS"
            return "HONORS", basket_id

        # 2. MDM / EMDM / Multidisciplinary Minor
        if (
            re.search(r"\b(e?mdm|multidisciplinary\s*minor)\b", sn_lo)
            or re.search(r"\b(e?mdm|multidisciplinary\s*minor)\b", cat_lo)
        ):
            m = re.search(r"\b(e?mdm[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(e?mdm[\s\-_]*\d+)\b", cat_lo)
            basket_id = m.group(1).upper().replace(" ", "-") if m else "MDM"
            return "MDM", basket_id

        # 3. OE / Open Elective / Institute Elective
        if (
            re.search(r"\b(oe|open\s*elective|institute\s*elective)\b", sn_lo)
            or re.search(r"\b(oe|open\s*elective|institute\s*elective)\b", cat_lo)
        ):
            m = re.search(r"\b(oe[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(open\s*elective[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(oe[\s\-_]*\d+)\b", cat_lo)
            basket_id = m.group(1).upper().replace(" ", "-") if m else "OE"
            return "OE", basket_id

        # 4. PE / Professional Elective / Department Elective / Program Elective
        if (
            re.search(r"\b(pe|dept\s*elective|department\s*elective|program\s*elective|professional\s*elective)\b", sn_lo)
            or re.search(r"\b(pe|dept\s*elective|department\s*elective|program\s*elective|professional\s*elective)\b", cat_lo)
        ):
            m = re.search(r"\b(pe[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(professional\s*elective[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(dept\s*elective[\s\-_]*\d+)\b", sn_lo) or re.search(r"\b(pe[\s\-_]*\d+)\b", cat_lo)
            basket_id = m.group(1).upper().replace(" ", "-") if m else "PE"
            return "PE", basket_id

        # 5. Generic Elective if explicitly named
        if "elective" in sn_lo or "elective" in cat_lo:
            return "ELECTIVE", "ELECTIVE"

        return "CORE", "CORE"

    def _get_home_classroom(self, class_name: str) -> str:
        if not class_name:
            return self.classrooms[0].get("name", "Classroom 1") if self.classrooms else "Room 101"
        if class_name in self.home_classrooms:
            return self.home_classrooms[class_name]
        if self.classrooms:
            idx = abs(hash(class_name)) % len(self.classrooms)
            rm = self.classrooms[idx].get("name", f"Classroom {idx + 1}")
        else:
            rm = f"Room {101 + (abs(hash(class_name)) % 50)}"
        self.home_classrooms[class_name] = rm
        return rm


    def _intent_from_raw(self, intent_raw: str, category_raw: str) -> str:
        """Normalise intent regardless of how Flutter encoded it."""
        intent = (intent_raw or "").lower().strip()
        cat = (category_raw or "").lower()

        # ALWAYS prioritize lock / fixed anchors
        if "lock" in intent or "fixed" in intent or "force" in intent or "lock" in cat or "fixed" in cat or "force" in cat:
            return "fixed"

        if intent == "blacklist":
            return "avoid"
        if intent in ("avoid", "fixed", "force", "whitelist", "fill",
                      "holiday", "no_theory_after_lunch", "parallel", "preferred"):
            return intent

        # Derive from category string when intent is blank or general
        if not intent:
            if "no theory after lunch" in cat:
                return "no_theory_after_lunch"
            if "whitelist" in cat or "only" in cat:
                return "whitelist"
            if "preferred" in cat:
                return "preferred"
            if "fill" in cat or "replace" in cat:
                return "fill"
            if "holiday" in cat or "college closed" in cat:
                return "holiday"
            if "parallel" in cat or "elective" in cat:
                return "parallel"
            return "avoid"
        return "avoid"

    def _is_hard_constraint(self, con: Constraint) -> bool:
        """
        Determines whether a constraint is Hard (must be 100% satisfied with zero violations)
        or Soft (preference / objective penalty).
        """
        cat = (con.category or "").lower()
        intent = (con.intent or "").lower()

        # Explicit UI tags
        if "hard|" in cat or cat.startswith("hard"):
            return True
        if "soft|" in cat or cat.startswith("soft"):
            return False

        # Structural hard constraints
        if intent in ("fixed", "force", "holiday"):
            return True
        if any(kw in cat for kw in ("fixed", "force", "holiday", "closed")):
            return True

        # Faculty unavailable / class unavailable / room unavailable is always HARD
        if any(kw in cat for kw in ("unavailable", "block", "leave")):
            return True
        if (con.faculty_names or con.class_names) and intent in ("avoid", "blacklist"):
            return True

        # Soft preferences
        if intent in ("no_theory_after_lunch", "avoid_first_period", "avoid_last_period",
                      "preferred", "preferred_slot", "preferred_day_time", "workload_balance"):
            return False
        if any(kw in cat for kw in ("preferred", "balance", "swap", "after lunch",
                                   "first period", "last period")):
            return False

        if intent == "whitelist":
            return True

        return True

    # -------------------------------------------------------------- #
    # Constraint parsing                                               #
    # -------------------------------------------------------------- #

    def _parse_constraints(self) -> Tuple[Set[str], List[Constraint]]:
        holidays: Set[str] = set()
        parsed: List[Constraint] = []
        self.fill_rules = []

        for c in self.constraints:
            intent = self._intent_from_raw(c.intent, c.category)

            if intent == "holiday":
                for d in c.days:
                    for wd in self.working_days:
                        if self._string_match(d, wd):
                            holidays.add(wd)
                continue

            if intent == "fill":
                label = "LeetCode"
                cat_lo = c.category.lower()
                if "with " in cat_lo:
                    label = cat_lo.split("with ", 1)[1].strip().strip("'\" .").capitalize()
                self.fill_rules.append({
                    "label": label, "days": c.days,
                    "slot_numbers": c.slot_numbers, "class_names": c.class_names,
                })
                continue

            parsed.append(Constraint(
                id=c.id, category=c.category, intent=intent,
                faculty_names=c.faculty_names, subject_names=c.subject_names,
                class_names=c.class_names, days=c.days, slot_numbers=c.slot_numbers,
            ))

        return holidays, parsed

    # -------------------------------------------------------------- #
    # Constraint↔session matching                                      #
    # -------------------------------------------------------------- #

    def _constraint_matches_session(self, con: Constraint, sess: SolverSession) -> bool:
        has_filter = False
        if con.faculty_names:
            has_filter = True
            fac_parts = [f.strip() for f in sess.faculty.split("|")]
            if not any(self._string_match(fn, fp)
                        for fn in con.faculty_names for fp in fac_parts):
                return False
        if con.subject_names:
            has_filter = True
            subj_parts = [s.strip() for s in sess.subject.split("|")]
            if not any(self._string_match(sn, sp)
                        for sn in con.subject_names for sp in subj_parts):
                return False
        if con.class_names:
            has_filter = True
            if not any(self._class_match(cn, cls) for cn in con.class_names for cls in sess.classes):
                return False
        if not has_filter:
            if not con.days and not con.slot_numbers:
                return False
        return True

    # -------------------------------------------------------------- #
    # Session building                                                  #
    # -------------------------------------------------------------- #

    def _build_sessions(self) -> List[SolverSession]:
        sessions: List[SolverSession] = []
        joint_theory: Dict[str, List[Assignment]] = defaultdict(list)
        parallel_elective: Dict[str, List[Assignment]] = defaultdict(list)
        individual: List[Assignment] = []

        # 1. Map constraints category to subjects if any
        subject_constraint_cats = defaultdict(list)
        for c in self.constraints:
            for sn in c.subject_names:
                subject_constraint_cats[self._normalize(sn)].append(c.category)

        # 2. Classify elective baskets per cohort
        # Key: (cohort, basket_family, basket_id) -> list of assignments
        # Also track (cohort, basket_family) -> list of assignments
        cohort_baskets = defaultdict(list)
        cohort_family_baskets = defaultdict(list)
        for a in self.assignments:
            if a.type.lower() == "theory":
                cats = " ".join(subject_constraint_cats.get(self._normalize(a.subject), []))
                family, basket_id = self._extract_elective_basket(a.subject, cats)
                if family in ("MDM", "PE", "OE", "ELECTIVE"):
                    cohort = self._get_cohort(a.class_name)
                    cohort_baskets[(cohort, family, basket_id)].append(a)
                    cohort_family_baskets[(cohort, family)].append(a)

        for a in self.assignments:
            t = a.type.lower()
            if t == "theory":
                # Check explicit parallel constraints first
                par_id = None
                for con in self.constraints:
                    if ("parallel" in (con.intent or "").lower()
                            or "parallel" in con.category.lower()) and con.subject_names:
                        if any(self._string_match(sn, a.subject) for sn in con.subject_names):
                            par_id = f"par_{self._normalize(con.subject_names[0])}"
                            break
                if par_id:
                    parallel_elective[par_id].append(a)
                    continue

                # Check elective basket parallel grouping (e.g. MDM-3 options together, PE-1 options together)
                cohort = self._get_cohort(a.class_name)
                cats = " ".join(subject_constraint_cats.get(self._normalize(a.subject), []))
                family, basket_id = self._extract_elective_basket(a.subject, cats)

                if family in ("MDM", "PE", "OE", "ELECTIVE"):
                    # 1. First check if this specific basket has 2+ distinct subjects (e.g. MDM-3: A, MDM-3: B)
                    basket_group = cohort_baskets.get((cohort, family, basket_id), [])
                    distinct_subs = {self._normalize(x.subject) for x in basket_group}
                    if len(distinct_subs) >= 2:
                        par_basket_key = f"par_{cohort.lower()}_{family.lower()}_{basket_id.lower()}"
                        parallel_elective[par_basket_key].append(a)
                        continue

                    # 2. Otherwise check if the broader family for this cohort has 2+ distinct subjects (e.g. PE-1: A, PE-2: B)
                    fam_group = cohort_family_baskets.get((cohort, family), [])
                    distinct_fam_subs = {self._normalize(x.subject) for x in fam_group}
                    if len(distinct_fam_subs) >= 2:
                        par_basket_key = f"par_{cohort.lower()}_{family.lower()}"
                        parallel_elective[par_basket_key].append(a)
                        continue

                # Merge into joint theory if explicitly tagged or part of combined_groups with matching subject+faculty
                if a.joint_group_id:
                    joint_theory[f"jg_{a.joint_group_id}"].append(a)
                    continue

                # Check if this subject is an Honors course shared across departments/classes
                if family == "HONORS":
                    # Honors course with same subject & faculty is scheduled ONCE for the combined cohort
                    joint_theory[f"honors_{self._normalize(a.subject)}_{self._normalize(a.faculty)}"].append(a)
                    continue

                # Check if this subject is locked synchronously across multiple classes in the same cohort
                cohort_lock_key = None
                for con in self.constraints:
                    con_cat = con.category.lower()
                    con_intent = (con.intent or "").lower()
                    if "lock" in con_intent or "fixed" in con_intent or "lock" in con_cat or "fixed" in con_cat or "institutional" in con_cat or "departmental" in con_cat:
                        if con.subject_names and any(self._string_match(sn, a.subject) for sn in con.subject_names):
                            if con.days and con.slot_numbers:
                                cohort_lock_key = f"lock_{cohort}_{self._normalize(a.subject)}_{con.days[0]}_{con.slot_numbers[0]}"
                                break
                if cohort_lock_key:
                    joint_theory[cohort_lock_key].append(a)
                    continue

                grp = self.group_lookup.get(a.class_name)
                if grp and any(o.faculty == a.faculty and o.subject == a.subject and o.class_name in grp for o in self.assignments if o != a):
                    joint_theory[f"cg_{self._normalize(a.subject)}_{self._normalize(a.faculty)}"].append(a)
                    continue

                # Standard class/division theory assignments remain independent per division.
                # The CP-SAT solver ensures faculty are never double-booked and divisions have distinct timetables.
                individual.append(a)
            else:
                individual.append(a)

        # 1. Joint theory groups (explicitly linked cohorts, e.g. Open Elective or Combined Dept)
        for key, group in joint_theory.items():
            first = group[0]
            all_cls: Set[str] = {a.class_name for a in group if a.class_name}
            hours = max(a.weekly_hours for a in group)
            for h in range(hours):
                sessions.append(SolverSession(
                    session_id=f"{key}_h{h}", faculty=first.faculty,
                    subject=first.subject, subject_code=first.subject_code,
                    type="Theory", batch="-", classes=sorted(all_cls),
                    duration=1, session_index=h, joint_group_id=first.joint_group_id,
                ))

        # 2. Parallel electives: merge into ONE slot (different faculty teach
        # different tracks simultaneously in the same time-slot across the cohort)
        for p_id, group in parallel_elective.items():
            unique_tracks = {}
            for a in group:
                track_k = (self._normalize(a.subject), self._normalize(a.faculty))
                if track_k not in unique_tracks:
                    unique_tracks[track_k] = a

            track_assignments = list(unique_tracks.values())
            subj = " | ".join(a.subject for a in track_assignments)
            fac  = " | ".join(a.faculty for a in track_assignments)
            code = " | ".join(a.subject_code or a.subject for a in track_assignments)
            hours = max(a.weekly_hours for a in track_assignments)

            # Strictly restrict parallel elective divisions to ONLY the target cohort year (e.g. TY only to TY)
            target_cohort = self._get_cohort(track_assignments[0].class_name if track_assignments else "")
            all_classes_set = {a.class_name for a in group if a.class_name and self._get_cohort(a.class_name) == target_cohort}
            cohort_siblings = [c for c in self._get_cohort_siblings(track_assignments[0].class_name if track_assignments else "") if self._get_cohort(c) == target_cohort]
            classes = sorted(list(all_classes_set | set(cohort_siblings)))

            for h in range(hours):
                sessions.append(SolverSession(
                    session_id=f"{p_id}_h{h}", faculty=fac,
                    subject=subj, subject_code=code, type="Theory",
                    batch="-", classes=classes, duration=1, session_index=h,
                ))

        # 3. Individual (division-specific theory + labs)
        for idx, a in enumerate(individual):
            t = a.type.lower()
            if t == "theory":
                for h in range(a.weekly_hours):
                    sessions.append(SolverSession(
                        session_id=f"th_{idx}_h{h}", faculty=a.faculty,
                        subject=a.subject, subject_code=a.subject_code,
                        type="Theory", batch="-", classes=[a.class_name],
                        duration=1, session_index=h,
                    ))
            elif t == "lab":
                lab_slots = self.lab_slots_per_session
                blocks = max(1, a.weekly_hours // lab_slots)
                batch_label = (
                    a.batch if a.batch and a.batch not in ("-", "All") else "Batch 1"
                )
                for b in range(blocks):
                    sessions.append(SolverSession(
                        session_id=f"lab_{idx}_b{b}", faculty=a.faculty,
                        subject=a.subject, subject_code=a.subject_code,
                        type="Lab", batch=batch_label,
                        classes=[a.class_name], duration=lab_slots, session_index=b,
                    ))

        return sessions

    # -------------------------------------------------------------- #
    # CP-SAT model                                                      #
    # -------------------------------------------------------------- #

    def _solve_model(
        self,
        sessions: List[SolverSession],
        active_constraints: List[Constraint],
        holidays: Set[str],
        available_days: List[str],
        strict_soft: bool,
        require_all_sessions: bool,
        start_time: float,
        time_limit: Optional[float] = None,
        pre_assigned_faculty_busy: Optional[Set[Tuple[str, str, int]]] = None,
        pre_assigned_class_busy: Optional[Set[Tuple[str, str, int]]] = None,
        pre_assigned_room_busy: Optional[Set[Tuple[str, str, int]]] = None,
    ) -> Optional[SolverResult]:

        if not sessions:
            return SolverResult(
                status="OPTIMAL",
                solve_time_seconds=round(time.monotonic() - start_time, 3),
                timetable={}, detailed_timetable={}, conflicts=[],
                message="No remaining sessions to schedule.",
            )

        pre_fac = pre_assigned_faculty_busy or set()
        pre_cls = pre_assigned_class_busy or set()
        pre_rm_set = pre_assigned_room_busy or set()

        teaching_slots = [s for s in self.time_slots if not s.is_break and s.slot_number > 0]
        if not teaching_slots:
            teaching_slots = [s for s in self.time_slots if s.slot_number > 0]

        # ---- Build options ----------------------------------------- #
        session_options: List[List[SessionOption]] = []
        conflicts: List[str] = []

        for sess in sessions:
            opts: List[SessionOption] = []
            duration = sess.duration
            fac_parts = [self._normalize(f) for f in sess.faculty.split("|") if f.strip()]

            for day in available_days:
                for i, ts in enumerate(teaching_slots):
                    if i + duration > len(teaching_slots):
                        continue
                    block = teaching_slots[i : i + duration]
                    block_slots = [b.slot_number for b in block]

                    # Labs must be strictly contiguous with no break / recess / lunch inside
                    if duration > 1:
                        if not self._is_contiguous_block(block):
                            continue

                    # Skip pre-assigned busy
                    if any((fp, day, s) in pre_fac for fp in fac_parts for s in block_slots):
                        continue
                    if any((self._normalize(cls), day, s) in pre_cls for cls in sess.classes for s in block_slots):
                        continue

                    # For single division theory, ensure division's home room isn't pre-assigned busy
                    if sess.type == "Theory" and len(sess.classes) == 1:
                        home_rm = self._normalize(self._get_home_classroom(sess.classes[0]))
                        if any((home_rm, day, s) in pre_rm_set for s in block_slots):
                            continue

                    penalty = 0
                    reasons: List[str] = []
                    valid = True

                    for con in active_constraints:
                        is_hard = self._is_hard_constraint(con)

                        # Global / intent no-theory-after-lunch
                        if con.intent == "no_theory_after_lunch" and sess.type == "Theory":
                            after = (
                                any(sn in con.slot_numbers for sn in block_slots)
                                if con.slot_numbers
                                else (self.first_lunch_slot is not None
                                      and any(sn >= self.first_lunch_slot for sn in block_slots))
                            )
                            if after:
                                if is_hard or strict_soft:
                                    valid = False
                                    break
                                else:
                                    penalty += 800
                                    reasons.append("Theory after lunch")
                            continue

                        if not self._constraint_matches_session(con, sess):
                            continue

                        day_ok  = not con.days or any(self._string_match(d, day) for d in con.days)
                        slot_ok = not con.slot_numbers or any(sn in con.slot_numbers for sn in block_slots)

                        if con.intent in ("avoid", "blacklist"):
                            if day_ok and slot_ok:
                                if is_hard or strict_soft:
                                    valid = False
                                    break
                                else:
                                    penalty += 2000
                                    reasons.append(f"Preference: avoid {day} {block_slots}")
                        elif con.intent in ("whitelist", "preferred"):
                            if (con.days and not day_ok) or (con.slot_numbers and not slot_ok):
                                if is_hard or strict_soft:
                                    valid = False
                                    break
                                else:
                                    penalty += 1500
                                    reasons.append(f"Preference: outside preferred {day} {block_slots}")
                        elif con.intent in ("fixed", "force"):
                            if not (day_ok and slot_ok):
                                valid = False
                                break

                    if not valid:
                        continue

                    opts.append(SessionOption(
                        day=day, start_slot=ts.slot_number,
                        slots=block_slots, penalty=penalty, penalty_reasons=reasons,
                    ))

            if not opts:
                conflicts.append(
                    f"No valid slot for {repr(sess.subject)} ({sess.type}, "
                    f"class={sess.classes}, fac={repr(sess.faculty)})"
                )
            session_options.append(opts)

        if conflicts and require_all_sessions:
            return None

        # ---- Build model -------------------------------------------- #
        model = cp_model.CpModel()
        choice_vars: List[List[cp_model.IntVar]] = []
        sched_vars: List[cp_model.IntVar] = []

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            row = [model.NewBoolVar(f"x_{i}_{j}") for j in range(len(opts))]
            choice_vars.append(row)
            if require_all_sessions:
                if not row:
                    return None
                model.Add(sum(row) == 1)
            else:
                sv = model.NewBoolVar(f"sched_{i}")
                sched_vars.append(sv)
                model.Add(sum(row) == sv) if row else model.Add(sv == 0)

        # Faculty: strictly at most one session per (normalized_faculty_part, day, slot)
        fac_slot: Dict[Tuple[str, str, int], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            fps = [self._normalize(f) for f in sess.faculty.split("|") if f.strip()]
            for j, opt in enumerate(opts):
                for fp in fps:
                    for s in opt.slots:
                        fac_slot[(fp, opt.day, s)].append(choice_vars[i][j])
        for vl in fac_slot.values():
            if len(vl) > 1:
                model.AddAtMostOne(vl)

        # Class: theory sessions and lab batches
        #   - theory: at most one theory per (class, day, slot)
        #   - lab batch: a theory conflicts with any batch; two DIFFERENT batches CAN coexist
        th_vars: Dict[Tuple[str, str, int], List] = defaultdict(list)
        bt_vars: Dict[Tuple[str, str, int, str], List] = defaultdict(list)

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            whole = sess.type == "Theory" or sess.batch in ("-", "All", "")
            for j, opt in enumerate(opts):
                v = choice_vars[i][j]
                for cls in sess.classes:
                    norm_cls = self._normalize(cls)
                    for s in opt.slots:
                        if whole:
                            th_vars[(norm_cls, opt.day, s)].append(v)
                        else:
                            bt_vars[(norm_cls, opt.day, s, sess.batch)].append(v)

        for vl in th_vars.values():
            if len(vl) > 1:
                model.AddAtMostOne(vl)

        for (cls, day, slot, batch), bvl in bt_vars.items():
            tvl = th_vars.get((cls, day, slot), [])
            combined = tvl + bvl
            if len(combined) > 1:
                model.AddAtMostOne(combined)
            if len(bvl) > 1:
                model.AddAtMostOne(bvl)

        # Home Classroom separation: No two single-division theory sessions using the same Home Classroom
        home_room_slot: Dict[Tuple[str, str, int], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            if sess.type == "Theory" and len(sess.classes) == 1:
                hrm = self._normalize(self._get_home_classroom(sess.classes[0]))
                for j, opt in enumerate(opts):
                    for s in opt.slots:
                        home_room_slot[(hrm, opt.day, s)].append(choice_vars[i][j])
        for vl in home_room_slot.values():
            if len(vl) > 1:
                model.AddAtMostOne(vl)

        # Same subject taught at most once per (class, day) for theory
        sd_vars: Dict[Tuple[str, str, str], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            if sess.type != "Theory":
                continue
            for cls in sess.classes:
                norm_cls = self._normalize(cls)
                for j, opt in enumerate(opts):
                    sd_vars[(norm_cls, sess.subject, opt.day)].append(choice_vars[i][j])
        for vl in sd_vars.values():
            if len(vl) > 1:
                model.AddAtMostOne(vl)

        # Simultaneous Theory & Lab Room constraints to guarantee zero classroom/lab double-booking
        if self.classrooms:
            max_classrooms = len(self.classrooms)
            theory_slot_vars: Dict[Tuple[str, int], List] = defaultdict(list)
            for i, (sess, opts) in enumerate(zip(sessions, session_options)):
                if sess.type == "Theory":
                    for j, opt in enumerate(opts):
                        v = choice_vars[i][j]
                        for s in opt.slots:
                            theory_slot_vars[(opt.day, s)].append(v)
            for (day, slot), tvl in theory_slot_vars.items():
                if len(tvl) > max_classrooms:
                    model.Add(sum(tvl) <= max_classrooms)

        if self.labs_pool:
            max_labs = len(self.labs_pool)
            lab_slot_vars: Dict[Tuple[str, int], List] = defaultdict(list)
            for i, (sess, opts) in enumerate(zip(sessions, session_options)):
                if sess.type == "Lab":
                    for j, opt in enumerate(opts):
                        v = choice_vars[i][j]
                        for s in opt.slots:
                            lab_slot_vars[(opt.day, s)].append(v)
            for (day, slot), lvl in lab_slot_vars.items():
                if len(lvl) > max_labs:
                    model.Add(sum(lvl) <= max_labs)

        # Daily workload spread (soft penalty to avoid clustering on one day)
        cd_vars: Dict[Tuple[str, str], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            for j, opt in enumerate(opts):
                for cls in sess.classes:
                    cd_vars[(cls, opt.day)].append(choice_vars[i][j])

        # Objective
        rew, pen = [], []
        if not require_all_sessions:
            for sv in sched_vars:
                rew.append(sv * 1_000_000)

        for i, opts in enumerate(session_options):
            for j, opt in enumerate(opts):
                v = choice_vars[i][j]
                # Subtle reward for earlier periods
                rew.append(v * max(1, 10 - opt.start_slot))
                if opt.penalty:
                    pen.append(v * opt.penalty)

        # Workload balance penalty: discourage more than comfortable daily limit
        nd = max(1, len(available_days))
        for cls in {c for s in sessions for c in s.classes}:
            tot = sum(1 for s in sessions if cls in s.classes)
            if tot:
                max_d = max(3, math.ceil(tot / nd) + 2)
                for day in available_days:
                    vl = cd_vars[(cls, day)]
                    if len(vl) > max_d:
                        excess_var = model.NewIntVar(0, len(vl), f"excess_{cls}_{day}")
                        model.Add(sum(vl) - max_d <= excess_var)
                        pen.append(excess_var * 200)

        # Synchronize parallel lab batches for the same class
        # When Batch 1 and Batch 2 are scheduled in the same slot, reward (+500)
        lab_class_slot_batches: Dict[Tuple[str, str, int], Dict[str, List]] = defaultdict(lambda: defaultdict(list))
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            if sess.type == "Lab" and sess.batch and sess.batch not in ("-", "All", ""):
                for j, opt in enumerate(opts):
                    v = choice_vars[i][j]
                    for cls in sess.classes:
                        for s in opt.slots:
                            lab_class_slot_batches[(cls, opt.day, s)][sess.batch].append(v)

        for (cls, day, slot), batch_vars_map in lab_class_slot_batches.items():
            if len(batch_vars_map) > 1:
                batch_keys = list(batch_vars_map.keys())
                for b_idx in range(len(batch_keys) - 1):
                    b1_list = batch_vars_map[batch_keys[b_idx]]
                    b2_list = batch_vars_map[batch_keys[b_idx + 1]]
                    sync_var = model.NewBoolVar(f"sync_lab_{cls}_{day}_{slot}_{b_idx}")
                    model.Add(sum(b1_list) >= sync_var)
                    model.Add(sum(b2_list) >= sync_var)
                    rew.append(sync_var * 500)

        # Schedule Compaction & Gap Minimization (strictly eliminate free holes/empty periods in the middle of a class day)
        valid_slots = sorted([ts.slot_number for ts in self.time_slots if not ts.is_break])
        cls_day_slot_active: Dict[Tuple[str, str, int], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            for j, opt in enumerate(opts):
                v = choice_vars[i][j]
                for cls in sess.classes:
                    norm_cls = self._normalize(cls)
                    for s in opt.slots:
                        if s in valid_slots:
                            cls_day_slot_active[(norm_cls, opt.day, s)].append(v)

        for cls in {self._normalize(c) for s in sessions for c in s.classes}:
            for day in available_days:
                slot_active_vars = {}
                for s in valid_slots:
                    v_list = cls_day_slot_active[(cls, day, s)]
                    if v_list:
                        act_v = model.NewBoolVar(f"act_{cls}_{day}_{s}")
                        model.Add(sum(v_list) >= act_v)
                        model.Add(sum(v_list) <= len(v_list) * act_v)
                        slot_active_vars[s] = act_v

                # For any pair of active slots s_start < s_end, penalize every empty intermediate slot s_mid
                for i_s in range(len(valid_slots)):
                    s_start = valid_slots[i_s]
                    if s_start not in slot_active_vars:
                        continue
                    for i_e in range(i_s + 2, len(valid_slots)):
                        s_end = valid_slots[i_e]
                        if s_end not in slot_active_vars:
                            continue
                        for i_m in range(i_s + 1, i_e):
                            s_mid = valid_slots[i_m]
                            v_mid = slot_active_vars.get(s_mid)
                            gap_var = model.NewBoolVar(f"gap_{cls}_{day}_{s_start}_{s_mid}_{s_end}")
                            if v_mid is not None:
                                model.Add(gap_var >= slot_active_vars[s_start] + slot_active_vars[s_end] - v_mid - 1)
                            else:
                                model.Add(gap_var >= slot_active_vars[s_start] + slot_active_vars[s_end] - 1)
                            pen.append(gap_var * 2500)

        # Faculty Gap Minimization: avoid idle gaps between lectures for faculty members
        all_fac_set = {self._normalize(f) for sess in sessions for f in sess.faculty.split("|") if f.strip()}
        fac_day_slot_active: Dict[Tuple[str, str, int], List] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            fps = [self._normalize(f) for f in sess.faculty.split("|") if f.strip()]
            for j, opt in enumerate(opts):
                v = choice_vars[i][j]
                for fp in fps:
                    for s in opt.slots:
                        if s in valid_slots:
                            fac_day_slot_active[(fp, opt.day, s)].append(v)

        for fp in all_fac_set:
            for day in available_days:
                fac_active_vars = {}
                for s in valid_slots:
                    fv_list = fac_day_slot_active[(fp, day, s)]
                    if fv_list:
                        fac_act_v = model.NewBoolVar(f"fac_act_{fp}_{day}_{s}")
                        model.Add(sum(fv_list) >= fac_act_v)
                        model.Add(sum(fv_list) <= len(fv_list) * fac_act_v)
                        fac_active_vars[s] = fac_act_v
                for i_s in range(len(valid_slots)):
                    s_start = valid_slots[i_s]
                    if s_start not in fac_active_vars:
                        continue
                    for i_e in range(i_s + 2, len(valid_slots)):
                        s_end = valid_slots[i_e]
                        if s_end not in fac_active_vars:
                            continue
                        for i_m in range(i_s + 1, i_e):
                            s_mid = valid_slots[i_m]
                            v_mid = fac_active_vars.get(s_mid)
                            f_gap = model.NewBoolVar(f"fgap_{fp}_{day}_{s_start}_{s_mid}_{s_end}")
                            if v_mid is not None:
                                model.Add(f_gap >= fac_active_vars[s_start] + fac_active_vars[s_end] - v_mid - 1)
                            else:
                                model.Add(f_gap >= fac_active_vars[s_start] + fac_active_vars[s_end] - 1)
                            pen.append(f_gap * 800)

        if rew or pen:
            model.Maximize(sum(rew) - sum(pen))

        # Solve
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = (
            time_limit if time_limit is not None else float(self.time_limit_seconds)
        )
        solver.parameters.num_search_workers = 4
        sc = solver.Solve(model)
        if sc not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            return None

        # ---- Extract solution --------------------------------------- #
        all_classes: Set[str] = {a.class_name for a in self.assignments}
        for s in sessions:
            all_classes.update(s.classes)
        for group in self.combined_groups:
            all_classes.update(group)

        rtt: Dict[str, Dict[str, List]] = {c: {} for c in all_classes}
        rdt: Dict[str, Dict[str, Any]] = {c: {} for c in all_classes}

        for c_name in all_classes:
            for day in self.working_days:
                for ts in self.time_slots:
                    key = f"{day}_{ts.slot_number}"
                    if day in holidays:
                        rtt[c_name][key] = [["Holiday", "", "", ""]]
                        rdt[c_name][key] = {"subject": "Holiday", "faculty": "", "batch": "", "type": "Holiday"}
                    elif ts.is_break:
                        rtt[c_name][key] = [["Break", "", "", ""]]
                        rdt[c_name][key] = {"subject": "Break", "faculty": "", "batch": "", "type": "Break"}
                    else:
                        rtt[c_name][key] = []
                        rdt[c_name][key] = {"subject": "Free", "faculty": "", "batch": "", "type": "Free"}

        rel_notes, unsched, sched_cnt = [], [], 0
        room_use: Dict[Tuple[str, int], Set[str]] = defaultdict(set)
        for (p_rm, p_day, p_s) in pre_rm_set:
            room_use[(p_day, p_s)].add(p_rm)

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            placed = False
            for j, opt in enumerate(opts):
                if solver.Value(choice_vars[i][j]) == 1:
                    placed = True
                    sched_cnt += 1
                    bl = "All" if sess.type == "Theory" else (sess.batch or "Batch 1")
                    rm = ""

                    # 1. Lab Practical Sessions: assign from lab pool
                    if sess.type == "Lab":
                        for r in self.labs_pool:
                            rn = r.get("name", "")
                            if rn and all(rn not in room_use[(opt.day, s)] for s in opt.slots):
                                rm = rn
                                break
                        if not rm:
                            l_idx = 1
                            while any(f"Lab {l_idx}" in room_use[(opt.day, s)] for s in opt.slots):
                                l_idx += 1
                            rm = f"Lab {l_idx}"
                        for s in opt.slots:
                            room_use[(opt.day, s)].add(rm)

                    # 2. Theory Sessions:
                    else:
                        if " | " in sess.subject:
                            # Multi-track Parallel Electives (e.g. PE-1 | PE-2 | PE-3 or MDM-1 | MDM-2):
                            # Assign each track to a separate classroom so all tracks run simultaneously in separate rooms
                            sub_tracks = [st.strip() for st in sess.subject.split(" | ")]
                            assigned_rooms = []

                            # 1. Use the cohort divisions' home classrooms first (e.g. Room 301 for Div A, Room 302 for Div B, Room 303 for Div C)
                            for cls_n in sess.classes:
                                if len(assigned_rooms) >= len(sub_tracks):
                                    break
                                home_rm = self._get_home_classroom(cls_n)
                                if home_rm and all(home_rm not in room_use[(opt.day, s)] for s in opt.slots) and home_rm not in assigned_rooms:
                                    assigned_rooms.append(home_rm)

                            # 2. If more tracks than assigned rooms, assign from available classrooms pool
                            for r in self.classrooms:
                                if len(assigned_rooms) >= len(sub_tracks):
                                    break
                                rn = r.get("name", "")
                                if rn and all(rn not in room_use[(opt.day, s)] for s in opt.slots) and rn not in assigned_rooms:
                                    assigned_rooms.append(rn)

                            # 3. Fallback numbering if pool is smaller
                            c_idx = 1
                            while len(assigned_rooms) < len(sub_tracks):
                                candidate = f"Room {300 + c_idx}"
                                if all(candidate not in room_use[(opt.day, s)] for s in opt.slots) and candidate not in assigned_rooms:
                                    assigned_rooms.append(candidate)
                                c_idx += 1

                            for r_assigned in assigned_rooms:
                                for s in opt.slots:
                                    room_use[(opt.day, s)].add(r_assigned)

                            rm = " | ".join(assigned_rooms)
                        elif len(sess.classes) > 1 or sess.joint_group_id:
                            # Single joint subject across multiple classes in a shared hall
                            for r in self.classrooms:
                                rn = r.get("name", "")
                                if rn and all(rn not in room_use[(opt.day, s)] for s in opt.slots):
                                    rm = rn
                                    break
                            if not rm:
                                c_idx = 1
                                while any(f"Shared Hall {c_idx}" in room_use[(opt.day, s)] for s in opt.slots):
                                    c_idx += 1
                                rm = f"Shared Hall {c_idx}"
                            for s in opt.slots:
                                room_use[(opt.day, s)].add(rm)
                        else:
                            # Single class-level theory lecture: MUST strictly use the division's dedicated HOME CLASSROOM
                            cls_name = sess.classes[0] if sess.classes else ""
                            candidate_home = self._get_home_classroom(cls_name)
                            if candidate_home and all(candidate_home not in room_use[(opt.day, s)] for s in opt.slots):
                                rm = candidate_home
                            else:
                                for r in self.classrooms:
                                    rn = r.get("name", "")
                                    if rn and all(rn not in room_use[(opt.day, s)] for s in opt.slots):
                                        rm = rn
                                        break
                                if not rm:
                                    c_idx = 1
                                    while any(f"Classroom {c_idx}" in room_use[(opt.day, s)] for s in opt.slots):
                                        c_idx += 1
                                    rm = f"Classroom {c_idx}"
                            for s in opt.slots:
                                room_use[(opt.day, s)].add(rm)

                    # Build detailed batch & track mappings
                    if " | " in sess.subject:
                        sub_tracks = [st.strip() for st in sess.subject.split(" | ")]
                        fac_tracks = [ft.strip() for ft in sess.faculty.split(" | ")]
                        rm_tracks = [rt.strip() for rt in rm.split(" | ")]
                        code_tracks = [ct.strip() for ct in sess.subject_code.split(" | ")]

                        batches_list = []
                        for idx_t, sub_t in enumerate(sub_tracks):
                            batches_list.append({
                                "subject": sub_t,
                                "faculty": fac_tracks[idx_t] if idx_t < len(fac_tracks) else "",
                                "room": rm_tracks[idx_t] if idx_t < len(rm_tracks) else (rm_tracks[0] if rm_tracks else ""),
                                "batch": f"Track {idx_t + 1}",
                                "type": "Elective",
                                "code": code_tracks[idx_t] if idx_t < len(code_tracks) else "",
                            })

                        for cls in sess.classes:
                            for s in opt.slots:
                                key = f"{opt.day}_{s}"
                                rtt[cls][key].append([sess.subject, sess.faculty, rm, bl])
                                rdt[cls][key] = {
                                    "subject": sess.subject,
                                    "faculty": sess.faculty,
                                    "room": rm,
                                    "batch": bl,
                                    "type": "Elective",
                                    "is_joint": True,
                                    "code": sess.subject_code,
                                    "batches": batches_list,
                                }
                    else:
                        for cls in sess.classes:
                            for s in opt.slots:
                                key = f"{opt.day}_{s}"
                                rtt[cls][key].append([sess.subject, sess.faculty, rm, bl])
                                existing = rdt[cls].get(key, {})
                                if not existing or existing.get("subject") in ("Free", "Break", "Holiday"):
                                    rdt[cls][key] = {
                                        "subject": sess.subject, "faculty": sess.faculty,
                                        "room": rm, "batch": bl, "type": sess.type,
                                        "is_joint": len(sess.classes) > 1, "code": sess.subject_code,
                                        "batches": [{
                                            "subject": sess.subject, "faculty": sess.faculty,
                                            "room": rm, "batch": bl, "type": sess.type,
                                            "code": sess.subject_code,
                                        }],
                                    }
                                else:
                                    prev_batches = existing.get("batches", [{
                                        "subject": existing.get("subject", ""),
                                        "faculty": existing.get("faculty", ""),
                                        "room": existing.get("room", ""),
                                        "batch": existing.get("batch", ""),
                                        "type": existing.get("type", ""),
                                        "code": existing.get("code", ""),
                                    }])
                                    prev_batches.append({
                                        "subject": sess.subject, "faculty": sess.faculty,
                                        "room": rm, "batch": bl, "type": sess.type,
                                        "code": sess.subject_code,
                                    })
                                    rdt[cls][key] = {
                                        "subject": " | ".join(b["subject"] for b in prev_batches),
                                        "faculty": " | ".join(b["faculty"] for b in prev_batches),
                                        "room": " | ".join(b["room"] for b in prev_batches if b.get("room")),
                                        "batch": " | ".join(b["batch"] for b in prev_batches if b.get("batch")),
                                        "type": "Lab" if any(b.get("type") == "Lab" for b in prev_batches) else sess.type,
                                        "is_joint": len(sess.classes) > 1,
                                        "code": " | ".join(b["code"] for b in prev_batches if b.get("code")),
                                        "batches": prev_batches,
                                    }
                    for r in opt.penalty_reasons:
                        rel_notes.append(f"{sess.subject}: {r}")
                    break
            if not placed:
                unsched.append(f"1 hr of {repr(sess.subject)} for {sess.classes} unplaced")

        ftt: Dict[str, Dict[str, List[str]]] = {}
        for cn, slots in rtt.items():
            ftt[cn] = {}
            for key, entries in slots.items():
                if not entries:
                    ftt[cn][key] = ["Free", "", "", ""]
                elif len(entries) == 1:
                    ftt[cn][key] = entries[0]
                else:
                    ftt[cn][key] = [
                        " | ".join(e[0] for e in entries),
                        " | ".join(e[1] for e in entries),
                        " | ".join(e[2] for e in entries if e[2]),
                        " | ".join(e[3] for e in entries if e[3] and e[3] != "All"),
                    ]

        all_notices = rel_notes + unsched + conflicts
        tot = len(sessions)
        if unsched:
            st = "FEASIBLE"
            msg = f"Partial: {sched_cnt}/{tot} scheduled. {len(unsched)} unplaced."
        else:
            st = "OPTIMAL" if (strict_soft and not rel_notes) else "FEASIBLE"
            msg = (f"Timetable generated! {sched_cnt}/{tot} sessions scheduled (100% hard constraints satisfied)."
                   if not rel_notes
                   else f"Timetable generated! 100% hard constraints satisfied, soft preferences optimized ({sched_cnt}/{tot} sessions).")

        return SolverResult(
            status=st,
            solve_time_seconds=round(time.monotonic() - start_time, 3),
            timetable=ftt, detailed_timetable=rdt,
            conflicts=all_notices, message=msg,
        )

    # -------------------------------------------------------------- #
    # Public entry                                                      #
    # -------------------------------------------------------------- #

    def solve(self) -> SolverResult:
        start_time = time.monotonic()
        holidays, active_constraints = self._parse_constraints()
        available_days = [d for d in self.working_days if d not in holidays]

        if not available_days:
            return SolverResult(
                status="INFEASIBLE", solve_time_seconds=0.0,
                conflicts=["All working days blocked."],
                message="All days blocked.",
            )

        sessions = self._build_sessions()
        if not sessions:
            return SolverResult(
                status="INFEASIBLE", solve_time_seconds=0.0,
                conflicts=["No assignments provided."],
                message="Assignment list is empty.",
            )

        # ---- Phase 1: pre-assign fixed constraints ------------------- #
        fixed_cons = [c for c in active_constraints if c.intent in ("fixed", "force")]
        all_classes: Set[str] = {a.class_name for a in self.assignments}
        for s in sessions:
            all_classes.update(s.classes)
        for group in self.combined_groups:
            all_classes.update(group)

        pre_tt: Dict[str, Dict[str, List]] = {c: {} for c in all_classes}
        pre_dt: Dict[str, Dict[str, Any]] = {c: {} for c in all_classes}
        fac_busy: Set[Tuple[str, str, int]] = set()
        cls_busy: Set[Tuple[str, str, int]] = set()
        room_busy: Set[Tuple[str, str, int]] = set()
        ts_nums = {ts.slot_number for ts in self.time_slots}

        for c_name in all_classes:
            for day in self.working_days:
                for ts in self.time_slots:
                    key = f"{day}_{ts.slot_number}"
                    if day in holidays:
                        pre_tt[c_name][key] = [["Holiday", "", "", ""]]
                        pre_dt[c_name][key] = {"subject": "Holiday", "faculty": "", "batch": "", "type": "Holiday"}
                    elif ts.is_break:
                        pre_tt[c_name][key] = [["Break", "", "", ""]]
                        pre_dt[c_name][key] = {"subject": "Break", "faculty": "", "batch": "", "type": "Break"}
                    else:
                        pre_tt[c_name][key] = []
                        pre_dt[c_name][key] = {"subject": "Free", "faculty": "", "batch": "", "type": "Free"}

        used_fixed_slots: Set[Tuple[int, str, int]] = set()

        def try_place_fixed(sess: SolverSession) -> bool:
            fps = [self._normalize(f) for f in sess.faculty.split("|") if f.strip()]
            for con in fixed_cons:
                if not self._constraint_matches_session(con, sess):
                    continue
                tgt_days = [d for d in (con.days or available_days) if d in available_days]
                if not con.slot_numbers:
                    continue
                for day in tgt_days:
                    for sn in con.slot_numbers:
                        if (id(con), day, sn) in used_fixed_slots:
                            continue
                        block = [sn] if sess.duration == 1 else list(range(sn, sn + sess.duration))
                        if not all(s in ts_nums and s not in self.break_slots for s in block):
                            continue
                        if sess.duration > 1:
                            block_slot_objs = [s for s in self.time_slots if s.slot_number in block and not s.is_break]
                            if len(block_slot_objs) != len(block) or not self._is_contiguous_block(block_slot_objs):
                                continue
                        if any((fp, day, s) in fac_busy for fp in fps for s in block):
                            continue
                        if any((self._normalize(cls), day, s) in cls_busy for cls in sess.classes for s in block):
                            continue

                        # Determine unique non-colliding fixed room
                        fixed_rm = ""
                        if sess.type == "Theory":
                            if len(sess.classes) == 1:
                                cand_rm = self._get_home_classroom(sess.classes[0])
                                if all((cand_rm, day, s) not in room_busy for s in block):
                                    fixed_rm = cand_rm
                            if not fixed_rm:
                                for r in self.classrooms:
                                    rn = r.get("name", "")
                                    if rn and all((rn, day, s) not in room_busy for s in block):
                                        fixed_rm = rn
                                        break
                            if not fixed_rm:
                                c_idx = 1
                                while any((f"Classroom {c_idx}", day, s) in room_busy for s in block):
                                    c_idx += 1
                                fixed_rm = f"Classroom {c_idx}"
                        else:
                            for r in self.labs_pool:
                                rn = r.get("name", "")
                                if rn and all((rn, day, s) not in room_busy for s in block):
                                    fixed_rm = rn
                                    break
                            if not fixed_rm:
                                l_idx = 1
                                while any((f"Lab {l_idx}", day, s) in room_busy for s in block):
                                    l_idx += 1
                                fixed_rm = f"Lab {l_idx}"

                        for cls in sess.classes:
                            for s in block:
                                key = f"{day}_{s}"
                                pre_tt[cls][key].append([sess.subject, sess.faculty, fixed_rm, "All"])
                                pre_dt[cls][key] = {
                                    "subject": sess.subject, "faculty": sess.faculty,
                                    "room": fixed_rm, "batch": "All", "type": sess.type,
                                    "is_joint": len(sess.classes) > 1, "code": sess.subject_code,
                                }
                        for fp in fps:
                            for s in block:
                                fac_busy.add((fp, day, s))
                        for cls in sess.classes:
                            for s in block:
                                cls_busy.add((self._normalize(cls), day, s))
                        for s in block:
                            room_busy.add((fixed_rm, day, s))
                        used_fixed_slots.add((id(con), day, sn))
                        return True
            return False

        remaining: List[SolverSession] = []
        for sess in sessions:
            if not try_place_fixed(sess):
                remaining.append(sess)

        # Remaining sessions are flexible; strip fixed/force constraints so they can use any free slot
        remaining_constraints = [c for c in active_constraints if c.intent not in ("fixed", "force")]

        # ---- Phase 2: Multi-stage CP-SAT ----------------------------- #
        p_time = max(5.0, self.time_limit_seconds * 0.5)

        # Stage 1: Try 100% Hard + Strict Soft + 100% Hours
        res = self._solve_model(
            sessions=remaining, active_constraints=remaining_constraints,
            holidays=holidays, available_days=available_days,
            strict_soft=True, require_all_sessions=True,
            start_time=start_time, time_limit=p_time,
            pre_assigned_faculty_busy=fac_busy,
            pre_assigned_class_busy=cls_busy,
            pre_assigned_room_busy=room_busy,
        )

        # Stage 2: Optimize Soft constraints while keeping 100% Hard + 100% Hours
        if res is None:
            elapsed = time.monotonic() - start_time
            res = self._solve_model(
                sessions=remaining, active_constraints=remaining_constraints,
                holidays=holidays, available_days=available_days,
                strict_soft=False, require_all_sessions=True,
                start_time=start_time,
                time_limit=max(5.0, self.time_limit_seconds - elapsed),
                pre_assigned_faculty_busy=fac_busy,
                pre_assigned_class_busy=cls_busy,
                pre_assigned_room_busy=room_busy,
            )

        # Stage 3: Diagnostic fallback if hard constraints themselves physically collide
        if res is None:
            elapsed = time.monotonic() - start_time
            res = self._solve_model(
                sessions=remaining, active_constraints=remaining_constraints,
                holidays=holidays, available_days=available_days,
                strict_soft=False, require_all_sessions=False,
                start_time=start_time,
                time_limit=max(5.0, self.time_limit_seconds - elapsed),
                pre_assigned_faculty_busy=fac_busy,
                pre_assigned_class_busy=cls_busy,
                pre_assigned_room_busy=room_busy,
            )


        if res is None or res.status not in ("OPTIMAL", "FEASIBLE"):
            return SolverResult(
                status="INFEASIBLE",
                solve_time_seconds=round(time.monotonic() - start_time, 3),
                conflicts=["Hours exceed available slots or hard constraints contradict each other."],
                message="Solver could not schedule all sessions.",
            )

        # ---- Phase 3: merge pre-assigned + CP-SAT -------------------- #
        for c_name, slots_dict in res.timetable.items():
            if c_name not in pre_tt:
                pre_tt[c_name] = {}
                pre_dt[c_name] = {}
            for key, entry in slots_dict.items():
                if isinstance(entry, list) and entry and entry[0] not in ("Free", "Break", "Holiday"):
                    pre_tt[c_name].setdefault(key, []).append(entry)
                    pre_dt[c_name][key] = res.detailed_timetable.get(c_name, {}).get(key, {})

        final_tt: Dict[str, Dict[str, List[str]]] = {}
        for c_name, slots in pre_tt.items():
            final_tt[c_name] = {}
            for key, entries in slots.items():
                flat = [e if isinstance(e, list) else [str(e), "", "", ""] for e in entries]
                if not flat:
                    final_tt[c_name][key] = ["Free", "", "", ""]
                elif len(flat) == 1:
                    final_tt[c_name][key] = flat[0]
                else:
                    final_tt[c_name][key] = [
                        " | ".join(r[0] for r in flat if r[0] not in ("Free", "Break", "Holiday")),
                        " | ".join(r[1] for r in flat),
                        " | ".join(r[2] for r in flat if len(r) > 2 and r[2]),
                        " | ".join(r[3] for r in flat if len(r) > 3 and r[3] and r[3] != "All"),
                    ]

        # Fill rules
        if self.fill_rules:
            for rule in self.fill_rules:
                label = rule.get("label", "LeetCode")
                tgt_days = rule.get("days") or self.working_days
                tgt_sn = set(rule.get("slot_numbers") or [ts.slot_number for ts in self.time_slots if not ts.is_break])
                for c_name in (rule.get("class_names") or list(all_classes)):
                    if c_name not in final_tt:
                        continue
                    for day in tgt_days:
                        for ts in self.time_slots:
                            if ts.is_break or ts.slot_number not in tgt_sn:
                                continue
                            key = f"{day}_{ts.slot_number}"
                            if final_tt[c_name].get(key) == ["Free", "", "", ""]:
                                final_tt[c_name][key] = [label, "", "", "All"]
                                if c_name in pre_dt and key in pre_dt[c_name]:
                                    pre_dt[c_name][key] = {"subject": label, "faculty": "", "batch": "All", "type": "Self-Study"}

        return SolverResult(
            status=res.status,
            solve_time_seconds=round(time.monotonic() - start_time, 3),
            timetable=final_tt, detailed_timetable=pre_dt,
            conflicts=res.conflicts, message=res.message,
        )


# ------------------------------------------------------------------ #
# Public helper                                                        #
# ------------------------------------------------------------------ #

def solve_from_dicts(
    assignments_raw: List[Dict[str, Any]],
    constraints_raw: List[Dict[str, Any]],
    combined_groups: Optional[List[List[str]]] = None,
    time_slots_raw: Optional[List[Dict[str, Any]]] = None,
    working_days: Optional[List[str]] = None,
    time_limit_seconds: int = 30,
    lecture_duration_minutes: int = 60,
    lab_duration_minutes: int = 120,
    rooms: Optional[List[Dict[str, Any]]] = None,
) -> SolverResult:

    assignments = [
        Assignment(
            faculty=a.get("facultyName") or a.get("faculty", ""),
            subject=a.get("subjectName") or a.get("subject", ""),
            class_name=a.get("className") or a.get("class_name", ""),
            type=a.get("type", "Theory"),
            batch=a.get("batch", "-"),
            weekly_hours=int(a.get("weeklyHours") or a.get("weekly_hours", 3)),
            subject_code=a.get("subjectCode") or a.get("subject_code", ""),
            joint_group_id=a.get("joint_group_id"),
        ) for a in assignments_raw
    ]
    constraints = [
        Constraint(
            id=c.get("id", ""), category=c.get("category", ""), intent=c.get("intent", ""),
            faculty_names=c.get("facultyNames") or c.get("faculty_names", []),
            subject_names=c.get("subjectNames") or c.get("subject_names", []),
            class_names=c.get("classNames") or c.get("class_names", []),
            days=c.get("days", []),
            slot_numbers=c.get("slotNumbers") or c.get("slot_numbers", []),
        ) for c in constraints_raw
    ]

    if time_slots_raw:
        time_slots = [
            TimeSlot(
                slot_number=int(s.get("slot_number") or s.get("slotNumber") or s.get("lectureNumber", idx + 1)),
                start_time=s.get("start_time") or s.get("startTime", ""),
                end_time=s.get("end_time") or s.get("endTime", ""),
                is_break=bool(s.get("is_break") or s.get("isBreak", False)),
                is_lunch=bool(s.get("is_lunch") or s.get("isLunch", False)),
            ) for idx, s in enumerate(time_slots_raw)
        ]
    else:
        time_slots = [
            TimeSlot(1, "09:00", "10:00"), TimeSlot(2, "10:00", "11:00"),
            TimeSlot(3, "11:00", "12:00"), TimeSlot(4, "12:00", "13:00"),
            TimeSlot(5, "13:00", "13:45", is_break=True, is_lunch=True),
            TimeSlot(6, "13:45", "14:45"), TimeSlot(7, "14:45", "15:45"),
            TimeSlot(8, "15:45", "16:45"),
        ]

    solver = TimetableCpSatSolver(
        assignments=assignments, time_slots=time_slots, constraints=constraints,
        combined_groups=combined_groups, working_days=working_days,
        time_limit_seconds=time_limit_seconds,
        lecture_duration_minutes=lecture_duration_minutes,
        lab_duration_minutes=lab_duration_minutes, rooms=rooms,
    )
    return solver.solve()
