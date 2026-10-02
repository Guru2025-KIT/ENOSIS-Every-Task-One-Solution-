"""
ScheduleConfig — global timetable configuration.

Stores everything the solver needs to know about the structure of a working
week: how many days, what time it starts and ends, how long each period is,
and which period slots are breaks/lunch (i.e. never get a class).

Only ONE active config row is expected at a time (the UI always upserts with
id='default'). Keeping it in the database means Android read-only views and
the web wizard both see the same config, and regeneration after a change
doesn't require re-entering everything from scratch.
"""
import uuid

from sqlalchemy import Column, String, Integer, Boolean, JSON

from app.db.base import Base


class ScheduleConfig(Base):
    __tablename__ = "schedule_config"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    # How many days in the working week (1–6, Mon=0 … Sat=5)
    working_days = Column(Integer, nullable=False, default=6)

    # Ordered list of day names, e.g. ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    day_names = Column(JSON, nullable=False, default=lambda: [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ])

    # Total teaching periods per day (break slots are included in this count
    # but no class is placed there — see break_slots below)
    periods_per_day = Column(Integer, nullable=False, default=8)

    # Duration of a single period in minutes (used for display; the solver
    # works in period-index space, not clock time)
    period_duration_minutes = Column(Integer, nullable=False, default=60)

    # Specific session durations configured by the user
    lecture_duration_minutes = Column(Integer, nullable=False, default=60)
    lab_duration_minutes = Column(Integer, nullable=False, default=120)
    tutorial_duration_minutes = Column(Integer, nullable=False, default=60)

    # Wall-clock start & end time of operating day, e.g. "09:00" and "17:00"
    start_time = Column(String(5), nullable=False, default="09:00")
    end_time = Column(String(5), nullable=False, default="17:00")

    # Explicit Break 1 & Break 2 configuration
    break1_enabled = Column(Boolean, nullable=False, default=True)
    break1_after_lectures = Column(Integer, nullable=False, default=2)
    break1_duration_minutes = Column(Integer, nullable=False, default=15)

    break2_enabled = Column(Boolean, nullable=False, default=True)
    break2_after_lectures = Column(Integer, nullable=False, default=5)
    break2_duration_minutes = Column(Integer, nullable=False, default=30)

    # List of period indices (0-based) that are breaks — the solver will
    # never place a class in these slots.
    # Example: [2, 5] → period 2 is short break, period 5 is lunch
    break_slots = Column(JSON, nullable=False, default=list)

    # Human-readable label for each break slot index, for display.
    # Example: {"2": "Short Break", "5": "Lunch Break"}
    break_labels = Column(JSON, nullable=False, default=dict)

    # Maximum lectures any single faculty member may teach per day (soft
    # cap stored here so the wizard can expose it; solver uses it as a
    # hard constraint when set, otherwise uncapped)
    max_lectures_per_day_per_faculty = Column(Integer, nullable=True)

    # College / department label — shown on the timetable header
    college_name = Column(String(255), nullable=True)
    department_name = Column(String(255), nullable=True)
    academic_year = Column(String(20), nullable=True)   # e.g. "2025-26"
    semester = Column(String(20), nullable=True)         # e.g. "Odd 2025"
    hod_name = Column(String(255), nullable=True)

    # Solver time budget in seconds
    time_limit_seconds = Column(Integer, nullable=False, default=30)

    def get_break_slots(self) -> list[int]:
        """Returns sorted list of 0-indexed period slots that are breaks."""
        slots = list(self.break_slots or [])
        if not slots:
            if self.break1_enabled and self.break1_after_lectures is not None:
                slots.append(self.break1_after_lectures)
            if self.break2_enabled and self.break2_after_lectures is not None:
                b1_offset = 1 if (self.break1_enabled and self.break1_after_lectures < self.break2_after_lectures) else 0
                slots.append(self.break2_after_lectures + b1_offset)
        return sorted(list(set(int(s) for s in slots if 0 <= int(s) < self.periods_per_day)))

    def get_lunch_slot(self) -> int | None:
        """Derives the lunch slot index from break labels, duration comparison, or break list."""
        labels = self.break_labels or {}
        for slot_str, label in labels.items():
            if "lunch" in str(label).lower():
                try:
                    return int(slot_str)
                except ValueError:
                    pass
        b_slots = self.get_break_slots()
        if not b_slots:
            return None
        if len(b_slots) == 1:
            return b_slots[0]
        if self.break2_enabled and (self.break2_duration_minutes or 0) >= (self.break1_duration_minutes or 0):
            return b_slots[-1]
        return b_slots[-1]

    def get_teaching_slots(self) -> list[int]:
        """All valid period indices that are NOT break slots."""
        breaks = set(self.get_break_slots())
        return [s for s in range(self.periods_per_day) if s not in breaks]

    def get_before_lunch_slots(self) -> list[int]:
        """Teaching slots occurring strictly before the lunch break."""
        lunch = self.get_lunch_slot()
        if lunch is None:
            teaching = self.get_teaching_slots()
            return teaching[:len(teaching) // 2]
        return [s for s in self.get_teaching_slots() if s < lunch]

    def get_after_lunch_slots(self) -> list[int]:
        """Teaching slots occurring strictly after the lunch break."""
        lunch = self.get_lunch_slot()
        if lunch is None:
            teaching = self.get_teaching_slots()
            return teaching[len(teaching) // 2:]
        return [s for s in self.get_teaching_slots() if s > lunch]

    def get_available_teaching_periods_per_week(self) -> int:
        """Total number of available class periods in a week for a single division."""
        return len(self.get_teaching_slots()) * (self.working_days or 6)

