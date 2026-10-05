"""
Standalone Google OR-Tools CP-SAT Timetable Solver.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Set, Tuple, Optional, Any, Union
from collections import defaultdict
import time
import re
import math
from ortools.sat.python import cp_model


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
    parallel_group_id: Optional[str] = None # ✅ NEW: For MDM/OE parallel electives

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
    faculty: str
    subject: str
    subject_code: str
    type: str
    batch: str
    classes: List[str]
    duration: int
    session_index: int
    parallel_group_id: Optional[str] = None # ✅ NEW

@dataclass
class SessionOption:
    day: str
    start_slot: int
    slots: List[int]
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
        rooms: Optional[List[Dict[str, Any]]] = None, # ✅ NEW: Accept rooms
    ):
        import math
        self.assignments = assignments
        self.time_slots = sorted(time_slots, key=lambda s: s.slot_number)
        self.constraints = constraints
        self.combined_groups = combined_groups or []
        self.working_days = working_days or ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        self.time_limit_seconds = time_limit_seconds
        self.lecture_duration_minutes = max(15, lecture_duration_minutes)
        self.lab_duration_minutes = max(15, lab_duration_minutes)
        self.lab_slots_per_session = max(1, math.ceil(self.lab_duration_minutes / self.lecture_duration_minutes))
        self.fill_rules: List[Dict[str, Any]] = []
        
        # ✅ Store Rooms
        self.rooms = rooms or []
        self.classrooms = [r for r in self.rooms if r.get('type', '').lower() != 'lab']
        self.labs = [r for r in self.rooms if r.get('type', '').lower() == 'lab']

        self.slot_by_num = {s.slot_number: s for s in self.time_slots if not s.is_break and s.slot_number > 0}
        self.break_slots = {s.slot_number for s in self.time_slots if s.is_break}
        
        self.lunch_slots = {s.slot_number for s in self.time_slots if s.is_lunch}
        if not self.lunch_slots and self.break_slots:
            mid = len(self.time_slots) // 2
            sorted_breaks = sorted(self.break_slots, key=lambda s: abs(s - mid))
            self.lunch_slots = {sorted_breaks[0]}
        
        self.first_lunch_slot = min(self.lunch_slots) if self.lunch_slots else None

        self.group_lookup: Dict[str, List[str]] = {}
        for group in self.combined_groups:
            for c in group:
                self.group_lookup[c] = group
                parent = c.rsplit('-', 1)[0]
                self.group_lookup.setdefault(parent, group)

    def _normalize(self, text: str) -> str:
        return text.strip().lower()

    def _string_match(self, pattern: str, target: str) -> bool:
        if not pattern or not target: return False
        p = pattern.lower().strip()
        t = target.lower().strip()
        if p == t or p in t or t in p: return True
        p_tokens = set(re.findall(r'\b[a-zA-Z0-9]{3,}\b', p))
        t_tokens = set(re.findall(r'\b[a-zA-Z0-9]{3,}\b', t))
        return bool(p_tokens and t_tokens and p_tokens.intersection(t_tokens))

    def _class_match(self, c1: str, c2: str) -> bool:
        if not c1 or not c2: return False
        n1 = c1.upper().replace("-", " ").strip()
        n2 = c2.upper().replace("-", " ").strip()
        return n1 == n2 or n1.startswith(n2) or n2.startswith(n1)

    def _parse_constraints(self) -> Tuple[Set[str], List[Constraint]]:
        holidays: Set[str] = set()
        parsed: List[Constraint] = []
        self.fill_rules = []

        for c in self.constraints:
            cat = c.category.lower()
            intent = c.intent.lower() if c.intent else ""

            if "holiday" in cat or intent == "holiday" or "college closed" in cat:
                for d in c.days:
                    for wd in self.working_days:
                        if self._string_match(d, wd): holidays.add(wd)
                continue

            if "fill" in cat or intent == "fill" or "replace" in cat:
                label = "LeetCode"
                if "with " in cat:
                    label_part = cat.split("with ", 1)[1].strip()
                    label = label_part.strip("'\" .").capitalize()
                elif "leetcode" in cat: label = "LeetCode"
                self.fill_rules.append({"label": label, "days": c.days, "slot_numbers": c.slot_numbers, "class_names": c.class_names})
                continue

            if not intent:
                if "fixed" in cat: intent = "fixed"
                elif "no theory after lunch" in cat: intent = "no_theory_after_lunch"
                elif "whitelist" in cat or "only" in cat: intent = "whitelist"
                elif "unavailable" in cat or "avoid" in cat or "blacklist" in cat: intent = "avoid"
                else: intent = "avoid"
            elif intent == "parallel":
                pass  

            parsed.append(Constraint(
                id=c.id, category=c.category, intent=intent,
                faculty_names=c.faculty_names, subject_names=c.subject_names,
                class_names=c.class_names, days=c.days, slot_numbers=c.slot_numbers
            ))
        return holidays, parsed

    def _constraint_matches_session(self, con: Constraint, sess: SolverSession) -> bool:
        has_filter = False
        if con.faculty_names:
            has_filter = True
            if not any(self._string_match(fn, sess.faculty) for fn in con.faculty_names): return False
        if con.subject_names:
            has_filter = True
            if not any(self._string_match(sn, sess.subject) for sn in con.subject_names): return False
        if con.class_names:
            has_filter = True
            if not any(any(self._class_match(cn, c_cls) for cn in con.class_names) for c_cls in sess.classes): return False
        if not has_filter:
            if not con.days and not con.slot_numbers: return False
        return True

    def _build_sessions(self) -> List[SolverSession]:
        sessions: List[SolverSession] = []
        joint_theory_groups: Dict[str, List[Assignment]] = defaultdict(list)
        parallel_groups: Dict[str, List[Assignment]] = defaultdict(list) # ✅ NEW
        individual_assignments: List[Assignment] = []

        def get_parent_key(c_name: str) -> str:
            if c_name in self.group_lookup: return "-".join(sorted(self.group_lookup[c_name]))
            parts = c_name.split('-')
            if len(parts) == 3: return f"{parts[0]}-{parts[1]}"
            return c_name

        for a in self.assignments:
            if a.type.lower() == "theory":
                # Check for Parallel Elective Constraint (MDM)
                parallel_id = None
                for con in self.constraints:
                    if con.intent == "parallel" and con.subject_names:
                        if any(self._string_match(sn, a.subject) for sn in con.subject_names):
                            parallel_id = f"parallel_{self._normalize(con.subject_names[0])}"
                            break
                
                if parallel_id:
                    parallel_groups[parallel_id].append(a)
                    continue

                # Check for standard joint groups (OE, B.Tech Honors)
                constraint_joint = None
                for con in self.constraints:
                    if con.subject_names and any(self._string_match(sn, a.subject) for sn in con.subject_names):
                        if con.intent == "fixed" or (len(con.class_names) > 1 and any(self._class_match(cn, a.class_name) for cn in con.class_names)):
                            constraint_joint = f"con_joint_{self._normalize(con.subject_names[0])}"
                            break

                parent = get_parent_key(a.class_name)
                if a.joint_group_id:
                    key = f"joint_{a.joint_group_id}"
                    joint_theory_groups[key].append(a)
                elif constraint_joint:
                    joint_theory_groups[constraint_joint].append(a)
                elif parent != a.class_name:
                    key = f"dept_{parent}_{self._normalize(a.faculty)}_{self._normalize(a.subject)}"
                    joint_theory_groups[key].append(a)
                else:
                    individual_assignments.append(a)
            else:
                individual_assignments.append(a)

        # Process joint theory groups
        for key, group in joint_theory_groups.items():
            first = group[0]
            all_classes = set()
            for a in group:
                if a.class_name in self.group_lookup: all_classes.update(self.group_lookup[a.class_name])
                else: all_classes.add(a.class_name)

            hours = max(a.weekly_hours for a in group)
            for h in range(hours):
                sessions.append(SolverSession(
                    session_id=f"{key}_sess_{h}", faculty=first.faculty, subject=first.subject,
                    subject_code=first.subject_code, type="Theory", batch="-",
                    classes=sorted(list(all_classes)), duration=1, session_index=h
                ))

        # ✅ Process Parallel Electives (MDM) - Keep separate, but link them
        for p_id, group in parallel_groups.items():
            for idx, a in enumerate(group):
                for h in range(a.weekly_hours):
                    sessions.append(SolverSession(
                        session_id=f"{p_id}_{idx}_sess_{h}", faculty=a.faculty, subject=a.subject,
                        subject_code=a.subject_code, type="Theory", batch="-",
                        classes=[a.class_name], duration=1, session_index=h,
                        parallel_group_id=p_id # ✅ Link them
                    ))

        # Process individual assignments
        for idx, a in enumerate(individual_assignments):
            if a.type.lower() == "theory":
                classes = self.group_lookup[a.class_name] if (
                    a.class_name in self.group_lookup and a.class_name not in self.group_lookup[a.class_name]
                ) else [a.class_name]

                for h in range(a.weekly_hours):
                    sessions.append(SolverSession(
                        session_id=f"indiv_theory_{idx}_sess_{h}", faculty=a.faculty, subject=a.subject,
                        subject_code=a.subject_code, type="Theory", batch="-",
                        classes=classes, duration=1, session_index=h
                    ))
            elif a.type.lower() == "lab":
                hours = a.weekly_hours
                lab_slots = self.lab_slots_per_session
                blocks = hours // lab_slots
                remainder = hours % lab_slots
                block_idx = 0

                for _ in range(blocks):
                    sessions.append(SolverSession(
                        session_id=f"lab_{idx}_blk_{block_idx}", faculty=a.faculty, subject=a.subject,
                        subject_code=a.subject_code, type="Lab",
                        batch=a.batch if a.batch else "Batch 1", classes=[a.class_name],
                        duration=lab_slots, session_index=block_idx
                    ))
                    block_idx += 1

                if remainder > 0:
                    sessions.append(SolverSession(
                        session_id=f"lab_{idx}_blk_{block_idx}_rem", faculty=a.faculty, subject=a.subject,
                        subject_code=a.subject_code, type="Theory", # Schedule as 1hr theory
                        batch=a.batch if a.batch else "Batch 1", classes=[a.class_name],
                        duration=1, session_index=block_idx
                    ))

        return sessions

    def _solve_model(
        self,
        sessions: List[SolverSession],
        active_constraints: List[Constraint],
        holidays: Set[str],
        available_days: List[str],
        strict: bool,
        start_time: float,
        time_limit: Optional[float] = None,
    ) -> Optional[SolverResult]:
        session_options: List[List[SessionOption]] = []
        conflicts: List[str] = []

        teaching_slots = [s for s in self.time_slots if not s.is_break and s.slot_number > 0]
        if not teaching_slots: teaching_slots = self.time_slots

        for sess in sessions:
            opts: List[SessionOption] = []
            duration = sess.duration

            for day in available_days:
                for idx, s in enumerate(teaching_slots):
                    start_slot = s.slot_number
                    if idx + duration > len(teaching_slots): continue

                    block_slice = teaching_slots[idx : idx + duration]
                    block_slots = [bs.slot_number for bs in block_slice]

                    if duration > 1 and (block_slots[-1] - block_slots[0]) != (duration - 1): continue

                    opt_penalty = 0
                    penalty_reasons = []
                    is_valid = True

                    for con in active_constraints:
                        if con.intent == "no_theory_after_lunch" and sess.type == "Theory":
                            after_lunch = False
                            if con.slot_numbers: after_lunch = any(sn in con.slot_numbers for sn in block_slots)
                            elif self.first_lunch_slot is not None: after_lunch = any(slot_num >= self.first_lunch_slot for slot_num in block_slots)

                            if after_lunch:
                                if strict: is_valid = False; break
                                else:
                                    opt_penalty += 1000
                                    penalty_reasons.append("Theory lecture scheduled after lunch")

                        if not self._constraint_matches_session(con, sess): continue

                        day_applies = not con.days or any(self._string_match(d, day) for d in con.days)

                        if con.intent == "avoid" and day_applies:
                            slot_clash = (not con.slot_numbers) or any(sn in con.slot_numbers for sn in block_slots)
                            if slot_clash:
                                if strict:
                                    is_valid = False; break
                                else:
                                    # ✅ FIX: Faculty Unavailable is a HARD constraint even in Soft Relaxation
                                    if "unavailable" in con.category.lower():
                                        is_valid = False; break
                                    opt_penalty += 10000
                                    penalty_reasons.append(f"Faculty/Subject preference avoided at {day} slot {block_slots}")

                        if con.intent == "whitelist":
                            day_bad = con.days and not day_applies
                            slot_bad = con.slot_numbers and not all(sn in con.slot_numbers for sn in block_slots)
                            if day_bad or slot_bad:
                                if strict: is_valid = False; break
                                else:
                                    opt_penalty += 10000
                                    penalty_reasons.append(f"Violates whitelist for {sess.subject}")

                        if con.intent in ("fixed", "force"):
                            day_bad = con.days and not day_applies
                            slot_bad = con.slot_numbers and not all(sn in con.slot_numbers for sn in block_slots)
                            if day_bad or slot_bad:
                                if strict: is_valid = False; break
                                else:
                                    opt_penalty += 50000
                                    penalty_reasons.append(f"Violates fixed slot requirement for {sess.subject}")

                    if is_valid or not strict:
                        opts.append(SessionOption(
                            day=day, start_slot=start_slot, slots=block_slots,
                            penalty=opt_penalty, penalty_reasons=penalty_reasons
                        ))

            if not opts:
                conflicts.append(f"No feasible time slot exists for session '{sess.subject}' ({sess.type}, classes={sess.classes}, faculty='{sess.faculty}').")
            session_options.append(opts)

        if conflicts and strict: return None

        model = cp_model.CpModel()
        choice_vars: List[List[cp_model.IntVar]] = []
        sched_vars: List[cp_model.IntVar] = []

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            row = [model.NewBoolVar(f"s_{i}_opt_{j}") for j in range(len(opts))]
            choice_vars.append(row)
            if strict: model.Add(sum(row) == 1)
            else:
                is_sched = model.NewBoolVar(f"sched_{i}")
                sched_vars.append(is_sched)
                model.Add(sum(row) == is_sched)

        # Faculty Exclusion
        faculty_slot_vars: Dict[Tuple[str, str, int], List[cp_model.IntVar]] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            for j, opt in enumerate(opts):
                var = choice_vars[i][j]
                for s in opt.slots: faculty_slot_vars[(sess.faculty, opt.day, s)].append(var)

        for (fac, day, slot), v_list in faculty_slot_vars.items():
            if len(v_list) > 1: model.AddAtMostOne(v_list)

        # Class Exclusion (Allows Parallel Batches)
        class_theory_vars: Dict[Tuple[str, str, int], List[cp_model.IntVar]] = defaultdict(list)
        class_batch_vars: Dict[Tuple[str, str, int, str], List[cp_model.IntVar]] = defaultdict(list)
        all_class_batches: Dict[str, Set[str]] = defaultdict(set)

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            for j, opt in enumerate(opts):
                var = choice_vars[i][j]
                for c_name in sess.classes:
                    for s in opt.slots:
                        if sess.type == "Theory" or sess.batch in ("-", "All", "Single Batch"):
                            class_theory_vars[(c_name, opt.day, s)].append(var)
                        else:
                            batch = sess.batch if sess.batch else "Batch 1"
                            all_class_batches[c_name].add(batch)
                            class_batch_vars[(c_name, opt.day, s, batch)].append(var)

        all_class_day_slots = set()
        for c_name, day, slot in class_theory_vars.keys(): all_class_day_slots.add((c_name, day, slot))
        for c_name, day, slot, _ in class_batch_vars.keys(): all_class_day_slots.add((c_name, day, slot))

        for c_name, day, slot in all_class_day_slots:
            t_vars = class_theory_vars[(c_name, day, slot)]
            if len(t_vars) > 1: model.AddAtMostOne(t_vars)

            batches = all_class_batches[c_name]
            if batches:
                for b in batches:
                    b_vars = class_batch_vars[(c_name, day, slot, b)]
                    all_vars_for_batch = t_vars + b_vars
                    if len(all_vars_for_batch) > 1: model.AddAtMostOne(all_vars_for_batch)

        # Spread Constraint
        subject_day_class_vars: Dict[Tuple[str, str, str], List[cp_model.IntVar]] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            if sess.type != "Theory": continue
            for c_name in sess.classes:
                for j, opt in enumerate(opts):
                    var = choice_vars[i][j]
                    subject_day_class_vars[(c_name, sess.subject, opt.day)].append(var)

        for (c_name, subj, day), v_list in subject_day_class_vars.items():
            if len(v_list) > 1: model.AddAtMostOne(v_list)

        # ✅ Parallel Elective Enforcement (MDM/OE)
        parallel_groups = defaultdict(list)
        for i, sess in enumerate(sessions):
            if sess.parallel_group_id: parallel_groups[sess.parallel_group_id].append(i)

        for p_gid, s_indices in parallel_groups.items():
            if len(s_indices) <= 1: continue
            for i in range(len(s_indices)):
                for j in range(i+1, len(s_indices)):
                    idx1 = s_indices[i]
                    idx2 = s_indices[j]
                    for opt1_idx, opt1 in enumerate(session_options[idx1]):
                        for opt2_idx, opt2 in enumerate(session_options[idx2]):
                            # If they don't share the exact same day and start slot, they cannot be chosen together
                            if not (opt1.day == opt2.day and opt1.start_slot == opt2.start_slot):
                                model.AddBoolOr([choice_vars[idx1][opt1_idx].Not(), choice_vars[idx2][opt2_idx].Not()])

        # Multi-Day Load Balancing
        class_day_total_vars: Dict[Tuple[str, str], List[cp_model.IntVar]] = defaultdict(list)
        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            for j, opt in enumerate(opts):
                var = choice_vars[i][j]
                for c_name in sess.classes: class_day_total_vars[(c_name, opt.day)].append(var)

        num_avail_days = max(1, len(available_days))
        for c_name in {c for s in sessions for c in s.classes}:
            total_class_sess = sum(1 for s in sessions if c_name in s.classes)
            if total_class_sess > 0:
                target_daily = math.ceil(total_class_sess / num_avail_days)
                max_daily_allowed = max(2, target_daily + 1)
                for day in available_days:
                    day_v_list = class_day_total_vars[(c_name, day)] # ✅ Fixed syntax error
                    if len(day_v_list) > max_daily_allowed:
                        if strict: model.Add(sum(day_v_list) <= max_daily_allowed)

        # Objective Function
        objective_rewards = []
        objective_penalty_terms = []

        if not strict and sched_vars:
            for is_sched in sched_vars: objective_rewards.append(is_sched * 100000)

        for i, opts in enumerate(session_options):
            for j, opt in enumerate(opts):
                var = choice_vars[i][j]
                weight = max(1, 10 - opt.start_slot)
                objective_rewards.append(var * weight)
                if opt.penalty > 0: objective_penalty_terms.append(var * opt.penalty)

        # Fixed Subject Slot Enforcement
        for con in active_constraints:
            if con.intent != "fixed" or not con.slot_numbers: continue

            matching_sess_indices = [i for i, sess in enumerate(sessions) if self._constraint_matches_session(con, sess)]
            if not matching_sess_indices: continue

            if con.days:
                for target_day in con.days:
                    if target_day not in available_days: continue
                    for target_slot in con.slot_numbers:
                        slot_match_vars = [
                            choice_vars[s_idx][opt_idx]
                            for s_idx in matching_sess_indices
                            for opt_idx, opt in enumerate(session_options[s_idx])
                            if opt.day == target_day and target_slot in opt.slots
                        ]
                        if slot_match_vars:
                            if strict: model.Add(sum(slot_match_vars) >= 1)
                            else:
                                is_fixed_met = model.NewBoolVar(f"fix_{con.id}_{target_day}_{target_slot}")
                                model.Add(sum(slot_match_vars) >= 1).OnlyEnforceIf(is_fixed_met)
                                objective_rewards.append(is_fixed_met * 50000)
            else:
                for s_idx in matching_sess_indices:
                    for opt_idx, opt in enumerate(session_options[s_idx]):
                        if any(sn in con.slot_numbers for sn in opt.slots):
                            objective_rewards.append(choice_vars[s_idx][opt_idx] * 20000)
                        elif strict: model.Add(choice_vars[s_idx][opt_idx] == 0)

        model.Maximize(sum(objective_rewards) - sum(objective_penalty_terms))

        # Solve
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = time_limit if time_limit is not None else float(self.time_limit_seconds)
        solver.parameters.num_search_workers = 4

        solver_status = solver.Solve(model)
        solve_time = round(time.monotonic() - start_time, 3)

        if solver_status not in (cp_model.OPTIMAL, cp_model.FEASIBLE): return None

        # Extract Timetable
        all_classes = set()
        for a in self.assignments:
            if a.class_name in self.group_lookup and a.class_name not in self.group_lookup[a.class_name]: all_classes.update(self.group_lookup[a.class_name])
            else: all_classes.add(a.class_name)
        for group in self.combined_groups: all_classes.update(group)

        timetable: Dict[str, Dict[str, List[List[str]]]] = {c: {} for c in all_classes} # ✅ Temporarily hold list of lists
        detailed: Dict[str, Dict[str, Any]] = {c: {} for c in all_classes}

        for c_name in all_classes:
            for day in self.working_days:
                for s in self.time_slots:
                    key = f"{day}_{s.slot_number}"
                    if day in holidays:
                        timetable[c_name][key] = [["Holiday", "", "", ""]]
                        detailed[c_name][key] = {"subject": "Holiday", "faculty": "", "batch": "", "type": "Holiday"}
                    elif s.is_break:
                        timetable[c_name][key] = [["Break", "", "", ""]]
                        detailed[c_name][key] = {"subject": "Break", "faculty": "", "batch": "", "type": "Break"}
                    else:
                        timetable[c_name][key] = []
                        detailed[c_name][key] = {"subject": "Free", "faculty": "", "batch": "", "type": "Free"}

        relaxed_notices = []
        unscheduled_notices = []
        scheduled_count = 0

        # ✅ Room Assignment Post-Processing Maps
        room_usage = defaultdict(set) # (day, slot) -> set of room names

        for i, (sess, opts) in enumerate(zip(sessions, session_options)):
            sess_was_placed = False
            for j, opt in enumerate(opts):
                if solver.Value(choice_vars[i][j]) == 1:
                    sess_was_placed = True
                    scheduled_count += 1
                    batch_info = "All" if sess.type == "Theory" else (sess.batch if sess.batch else "Batch 1")
                    
                    # ✅ Dynamic Room Assignment
                    assigned_room = ""
                    if self.rooms:
                        available_pool = self.labs if sess.type == "Lab" else self.classrooms
                        for room in available_pool:
                            r_name = room.get('name', '')
                            if r_name and r_name not in room_usage[(opt.day, opt.slots[0])]:
                                assigned_room = r_name
                                room_usage[(opt.day, opt.slots[0])].add(assigned_room)
                                break
                    
                    for c_name in sess.classes:
                        for s in opt.slots:
                            key = f"{opt.day}_{s}"
                            timetable[c_name][key].append([sess.subject, sess.faculty, assigned_room, batch_info])
                            detailed[c_name][key] = {
                                "subject": sess.subject, "faculty": sess.faculty,
                                "room": assigned_room, "batch": batch_info, "type": sess.type,
                                "is_joint": len(sess.classes) > 1, "code": sess.subject_code
                            }
                    if opt.penalty_reasons:
                        for r in opt.penalty_reasons: relaxed_notices.append(f"{sess.subject} ({sess.faculty}): {r}")
                    break

            if not sess_was_placed and not strict:
                unscheduled_notices.append(f"1 hr of {sess.subject} ({sess.faculty} for {', '.join(sess.classes)}) could not fit into the available week slots")

        # ✅ Flatten timetable back to List[str] using " | " for parallel sessions
        final_timetable: Dict[str, Dict[str, List[str]]] = {c: {} for c in all_classes}
        for c_name, slots_dict in timetable.items():
            for key, entries in slots_dict.items():
                if not entries:
                    final_timetable[c_name][key] = ["Free", "", "", ""]
                elif len(entries) == 1:
                    final_timetable[c_name][key] = entries[0]
                else:
                    # Join parallel sessions (e.g., MDM Finance | MDM Bio)
                    subj = " | ".join([e[0] for e in entries])
                    fac = " | ".join([e[1] for e in entries])
                    room = " | ".join([e[2] for e in entries if e[2]])
                    batch = " | ".join([e[3] for e in entries if e[3] and e[3] != "All"])
                    final_timetable[c_name][key] = [subj, fac, room, batch]

        if unscheduled_notices:
            all_notices = relaxed_notices + unscheduled_notices
            return SolverResult(
                status="FEASIBLE", solve_time_seconds=solve_time,
                timetable=final_timetable, detailed_timetable=detailed,
                conflicts=all_notices,
                message=f"Timetable generated with partial placement: {scheduled_count} of {len(sessions)} hours scheduled. {len(unscheduled_notices)} session(s) could not fit."
            )

        status_name = "OPTIMAL" if (strict and not relaxed_notices) else "FEASIBLE"
        all_notices = relaxed_notices
        msg = f"Timetable generated successfully! ({scheduled_count} hours scheduled)" if not all_notices else f"Timetable generated with optimization! ({scheduled_count} of {len(sessions)} hours scheduled)"

        return SolverResult(
            status=status_name, solve_time_seconds=solve_time,
            timetable=final_timetable, detailed_timetable=detailed,
            conflicts=all_notices, message=msg
        )

    def solve(self) -> SolverResult:
        start_time = time.monotonic()

        holidays, active_constraints = self._parse_constraints()
        available_days = [d for d in self.working_days if d not in holidays]

        if not available_days:
            return SolverResult(status="INFEASIBLE", solve_time_seconds=0.0, conflicts=["All working days are marked as holidays."], message="All days blocked as holidays.")

        sessions = self._build_sessions()
        if not sessions:
            return SolverResult(status="INFEASIBLE", solve_time_seconds=0.0, conflicts=["No assignments provided."], message="Assignment list is empty.")

        pass1_limit = max(5.0, self.time_limit_seconds * 0.6)
        res = self._solve_model(
            sessions=sessions, active_constraints=active_constraints, holidays=holidays,
            available_days=available_days, strict=True, start_time=start_time, time_limit=pass1_limit,
        )

        if res is None:
            elapsed = time.monotonic() - start_time
            pass2_limit = max(5.0, self.time_limit_seconds - elapsed)
            res = self._solve_model(
                sessions=sessions, active_constraints=active_constraints, holidays=holidays,
                available_days=available_days, strict=False, start_time=start_time, time_limit=pass2_limit,
            )

        if res is None or res.status not in ("OPTIMAL", "FEASIBLE"):
            return SolverResult(
                status="INFEASIBLE", solve_time_seconds=round(time.monotonic() - start_time, 3),
                conflicts=["Total assigned lecture and lab hours exceed the available slots, or mutual teacher commitments make scheduling impossible."],
                message="Solver could not schedule all hours within the available time slots."
            )

        if self.fill_rules and res.timetable:
            for f_rule in self.fill_rules:
                label = f_rule.get("label", "LeetCode")
                target_days = f_rule.get("days") or self.working_days
                target_slots = set(f_rule.get("slot_numbers") or [s.slot_number for s in self.time_slots if not s.is_break])
                for c_name, grid in res.timetable.items():
                    for day in target_days:
                        for s in self.time_slots:
                            if not s.is_break and (not target_slots or s.slot_number in target_slots):
                                key = f"{day}_{s.slot_number}"
                                if grid.get(key) == ["Free", "", "", ""]:
                                    grid[key] = [label, "", "", "All"]
                                    if c_name in res.detailed_timetable and key in res.detailed_timetable[c_name]:
                                        res.detailed_timetable[c_name][key] = {"subject": label, "faculty": "", "batch": "All", "type": "Self-Study"}

        return res


def solve_from_dicts(
    assignments_raw: List[Dict[str, Any]],
    constraints_raw: List[Dict[str, Any]],
    combined_groups: Optional[List[List[str]]] = None,
    time_slots_raw: Optional[List[Dict[str, Any]]] = None,
    working_days: Optional[List[str]] = None,
    time_limit_seconds: int = 30,
    lecture_duration_minutes: int = 60,
    lab_duration_minutes: int = 120,
    rooms: Optional[List[Dict[str, Any]]] = None, # ✅ Accept rooms
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
            joint_group_id=a.get("joint_group_id")
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
            TimeSlot(slot_number=1, start_time="09:00", end_time="10:00"), TimeSlot(slot_number=2, start_time="10:00", end_time="11:00"),
            TimeSlot(slot_number=3, start_time="11:00", end_time="12:00"), TimeSlot(slot_number=4, start_time="12:00", end_time="01:00"),
            TimeSlot(slot_number=5, start_time="01:00", end_time="01:45", is_break=True, is_lunch=True), TimeSlot(slot_number=6, start_time="01:45", end_time="02:45"),
            TimeSlot(slot_number=7, start_time="02:45", end_time="03:45"), TimeSlot(slot_number=8, start_time="03:45", end_time="04:45"),
        ]

    solver = TimetableCpSatSolver(
        assignments=assignments, time_slots=time_slots, constraints=constraints,
        combined_groups=combined_groups, working_days=working_days,
        time_limit_seconds=time_limit_seconds, lecture_duration_minutes=lecture_duration_minutes,
        lab_duration_minutes=lab_duration_minutes, rooms=rooms, # ✅ Pass rooms
    )
    return solver.solve()