# 🎓 ENOSIS: Every Task. One Solution.
## Master Project Presentation & Comprehensive Viva Guide

---

## 1. Executive Summary & Overall Project Idea

### What is ENOSIS?
**ENOSIS** (derived from the Greek word for *"Unity"* or *"Oneness"*) is an all-in-one, intelligent **Academic Operating System (AOS)** designed specifically for engineering colleges, universities, and autonomous institutions.

### The Problem It Solves
Modern colleges operate in an extremely fragmented and inefficient manner:
1. **Timetable Chaos**: Timetable coordinators spend 2 to 3 weeks every semester manually juggling dozens of divisions, faculty members, and lab rooms on Excel sheets, frequently resulting in teacher double-booking, room clashes, and continuous exhaustion.
2. **Accreditation Paperwork Nightmares**: Calculating **CO-PO (Course Outcome – Program Outcome) attainment** for NBA/NAAC accreditation involves hundreds of disconnected spreadsheets, taking weeks of manual math and prone to human calculation errors.
3. **Late Student Failure Detection**: Underperforming or at-risk students are typically detected only *after* final semester results are published—when it is already too late for remedial intervention.
4. **Faculty Tool Fatigue**: Teachers waste valuable academic hours switching between 5+ separate software applications for daily schedules, attendance, task planning, career achievements, and curriculum tracking.

### The ENOSIS Solution
ENOSIS unifies all administrative, scheduling, accreditation, and instructional workflows into **one cohesive, responsive platform**:
- **Zero-Clash Automated Scheduling**: Mathematical constraint solver generates semester timetables in 2–5 seconds with a 100% hard constraint guarantee.
- **Automated NBA / NAAC Outcome Computation**: Real-time CO-PO attainment matrices with 1-click audit-ready Excel reports.
- **Student Learning Intelligence (SLI)**: A 3-stage longitudinal assessment framework (**PRE $\rightarrow$ MID $\rightarrow$ END**) tracking student learning trajectories from day one to final mastery.
- **Predictive Academic Risk Alerting**: Detects learning drop-offs and flags at-risk students before final examinations.
- **Faculty Command Center**: Real-time "Today's Schedule", PBAS career advancement portfolio, and integrated academic to-do planner.
- **Context-Aware AI Assistant**: Voice-enabled institutional assistant grounded in the college's actual syllabus and live schedule.

---

## 2. Complete Technology Stack & What Each Component Is

| Layer | Technology | Version | What It Is & Exact Role |
| :--- | :--- | :--- | :--- |
| **Frontend Framework** | **Flutter** | 3.24+ | Google's cross-platform UI framework written in **Dart**. Compiles to native web assembly/JavaScript for Chrome/Edge browsers, as well as Android, iOS, and desktop apps from a single codebase. |
| **Frontend Architecture** | **Provider Pattern** | 6.x | Reactive state management pattern in Flutter that separates UI widgets from business logic, ensuring instant reactivity when schedules or assessments update. |
| **Backend API Engine** | **FastAPI** | 0.110+ | A modern, asynchronous, high-performance web framework for Python based on standard Python type hints, Starlette, and Pydantic. Handles REST endpoints with auto-generated OpenAPI documentation. |
| **Optimization Solver** | **Google OR-Tools CP-SAT** | 9.8+ | An industrial-strength combinatorial optimization engine developed by Google Operations Research. Solves NP-Hard scheduling problems using Boolean Satisfiability (SAT) and Constraint Programming (CP). |
| **ORM / Data Access** | **SQLAlchemy** | 2.0+ | Python's leading Object Relational Mapper that abstracts database interactions into Python classes and type-safe queries. |
| **Primary Relational DB** | **MySQL** | 8.0+ | ACID-compliant relational database management system running in a Docker container, storing structured academic records, user credentials, and timetable entries. |
| **Testing Database** | **SQLite** | In-Memory | Lightweight, serverless relational database used for ultra-fast, isolated automated unit and integration tests (200+ tests). |
| **Client Storage / Cache** | **SharedPreferences / LocalStorage** | Web/Mobile | Key-value browser/device storage used to cache JWT tokens, user profiles, and published timetable grids for offline resilience. |
| **Cloud Asset Vault** | **Cloudinary API** | REST | Cloud-hosted digital asset storage for faculty research papers, certificates, and institutional approval PDFs. |
| **AI / NLP Engine** | **Groq LLaMA-3 / Gemini** | Cloud API | High-speed LLM inference engine providing academic advice, RAG over the college curriculum, and automated question drafting. |
| **Voice Synthesis** | **ElevenLabs API** | REST | Neural text-to-speech engine providing lifelike voice feedback for accessibility and hands-free faculty interaction. |
| **Containerization** | **Docker & Docker Compose** | Latest | Container orchestration packaging Frontend (Nginx:5000), Backend (FastAPI:8000), and Database (MySQL:3307) into isolated, reproducible microservices. |

---

## 3. Database Architecture: Which Database is Used for Which Module?

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ENOSIS DATA TOPOLOGY                            │
├────────────────────────────────────────────────────────────────────────┤
│ 1. MySQL 8.0 (Production Server - Port 3307/3306)                      │
│    ├── Core Academic: divisions, subjects, rooms, teaching_assignments │
│    ├── Timetable: timetable_entries, generation_runs, schedule_configs │
│    ├── SLI Engine: sli_assessments, sli_questions, sli_submissions     │
│    ├── NBA/NAAC: co_po_mappings, co_po_attainment_configs             │
│    ├── User & Security: users (RBAC: Admin, Timetable Manager, Faculty)│
│    ├── Career (PBAS): achievements, publication_records                │
│    └── Task Planner: todos, todo_subtasks                              │
├────────────────────────────────────────────────────────────────────────┤
│ 2. SharedPreferences & HTML5 LocalStorage (Client Side)                │
│    ├── JWT Access Tokens & Refresh Tokens                              │
│    ├── Active Session Profile (Permissions & Role state)               │
│    └── Offline Cached Published Timetable (Zero network delay)         │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Cloudinary CDN (Cloud Media Vault)                                  │
│    └── Research papers, conference certificates, appraisal documents   │
├────────────────────────────────────────────────────────────────────────┤
│ 4. SQLite (Isolated Testing Environment)                               │
│    └── Runs in-memory during pytest test suites without polluting prod │
└────────────────────────────────────────────────────────────────────────┘
```

### Detailed Breakdown by Module:

| Module | Storage Used | Tables / Keys | Why This Specific Storage? |
| :--- | :--- | :--- | :--- |
| **User Management & RBAC** | **MySQL 8.0** | `users` | Requires strict ACID transactions, unique email indexing, and bcrypt hashed password security. |
| **Timetable Scheduling** | **MySQL 8.0** + **SharedPreferences** | `timetable_entries`, `generation_runs`, `schedule_configs`, `timetable_constraints` | Foreign-key integrity ensures a lecture cannot point to a deleted teacher or room. `GenerationRun.config_snapshot` stores JSON snapshots. Client-side `SharedPreferences` caches the published grid so faculty see their schedule even offline. |
| **CO-PO Attainment** | **MySQL 8.0** | `co_po_mappings`, `co_po_attainment_configs`, `student_scores` | Relational tables enable structured joins between Course Outcomes (CO1-CO6) and Program Outcomes (PO1-PO12) to compute dot-product attainment matrices. |
| **Student Learning Intelligence (SLI)** | **MySQL 8.0** | `sli_departments`, `sli_semesters`, `academic_classes`, `students`, `enrollments`, `sli_assessments`, `sli_questions`, `sli_submissions`, `sli_responses`, `sli_interventions` | Heavy relational linkages: each submission references student, assessment, specific question, and chosen option, allowing longitudinal tracking. |
| **Faculty Career (PBAS)** | **MySQL 8.0** + **Cloudinary** | `achievements` (MySQL) + PDF Blobs (Cloudinary) | Structured metadata (title, journal, impact factor, date) lives in MySQL; large binary PDFs and certificates live on Cloudinary CDN for fast streaming. |
| **Task / To-Do Planner** | **MySQL 8.0** | `todos`, `todo_subtasks` | Persistent storage with parent-child foreign key cascading (deleting a task automatically cleans its subtasks). |
| **AI Assistant** | **In-Memory Dynamic Context** | Ephemeral context injection | The assistant dynamically pulls the logged-in user's profile and active timetable from MySQL on every prompt to ground answers without hallucinations. |

---

## 4. Key Working Modules & Their Algorithmic Foundations

### Module 1: Automated Timetable Engine
- **Algorithm**: **Google OR-Tools CP-SAT (Constraint Programming + Boolean Satisfiability)**.
- **Why this algorithm**: Timetable generation is an **NP-Hard Combinatorial Problem**. 
  - Brute force takes $O(S^N)$ time (years to run).
  - Genetic Algorithms (GA) produce random clashes and cannot guarantee 100% hard rule compliance.
  - CP-SAT uses **Conflict-Driven Clause Learning (CDCL)**: whenever a partial schedule creates a clash, it mathematically proves why and cuts off millions of invalid branches in milliseconds.
- **Key Constraints Solved**:
  - **Faculty Clashes**: $\sum x_{i,j} \le 1$ for all sessions of a faculty on `(day, slot)`—**zero double-booking**.
  - **Class Overlaps**: Whole class lectures and batch labs cannot overlap.
  - **Lab Continuity**: Enforces atomic 2-hour blocks (`duration = 2`) that never cross lunch or recess.
  - **Parallel Batch Synchronization**: Batch 1 and Batch 2 run in parallel at the same time window, but with **different subjects and different teachers in different labs** (`sync_lab` reward $+3000$).
  - **Room Capacity**: Guarantees classroom and lab pools are never oversubscribed.

---

### Module 2: CO-PO Attainment & Curriculum Mapping (NBA / NAAC)
- **Algorithm**: **Multi-Level Matrix Dot-Product Attainment Transformation**.
- **Formula & Math**:
  1. **Direct Attainment**:
     $$\text{CO Direct} = (w_{\text{internal}} \times \text{Attainment}_{\text{internal}}) + (w_{\text{external}} \times \text{Attainment}_{\text{external}})$$
     *(Default: 20% Internal Assessment + 80% End-Semester Examination)*
  2. **Total CO Attainment**:
     $$\text{CO Total} = (0.8 \times \text{CO Direct}) + (0.2 \times \text{CO Indirect (Student Exit Survey)})$$
  3. **PO Attainment Matrix Multiplication**:
     $$\text{PO}_j = \frac{\sum_{i=1}^{6} (\text{CO}_i \times M_{i,j})}{\sum_{i=1}^{6} M_{i,j}}$$
     where $M_{i,j} \in \{0, 1, 2, 3\}$ is the curriculum correlation matrix (0 = No correlation, 1 = Slight, 2 = Moderate, 3 = Substantial).
- **Why this algorithm**: It is the exact standard mathematical formulation required by the **National Board of Accreditation (NBA)** and **NAAC Criterion 2.6**. Automating this eliminates human transcription errors across academic departments.

---

### Module 3: Student Learning Intelligence (SLI) Assessment Framework
- **Algorithm**: **3-Stage Longitudinal Cognitive Progression + Bloom's Taxonomy Mapping**.
- **The 3 Stages**:
  1. **PRE-Assessment (Diagnostic)**: Evaluates foundational prerequisites and student confidence before teaching starts.
  2. **MID-Assessment (Formative)**: Administered mid-semester to identify specific conceptual bottlenecks, alerting teachers for 1-on-1 remedial counseling.
  3. **END-Assessment (Summative)**: Measures overall topic mastery and directly feeds into Course Outcome (CO) attainment.
- **Cognitive Mapping**: Each question is tagged with Bloom’s Taxonomy levels:
  - $L_1$: Remember, $L_2$: Understand, $L_3$: Apply, $L_4$: Analyze, $L_5$: Evaluate, $L_6$: Create.
- **Why this algorithm**: Traditional exams only give a final percentage after the semester ends. SLI provides early, formative, diagnostic intelligence while there is still time to intervene.

---

### Module 4: Machine Learning Academic Risk Predictor
- **Algorithm**: **Supervised Multi-Factor Risk Scoring & Logistic Regression / Random Forest Classifier**.
- **Input Features**:
  - Attendance Percentage ($\%$)
  - PRE-Assessment confidence score
  - MID-Assessment quiz performance
  - Assignment submission timeliness
  - Historical semester SGPA/CGPA
- **Output**:
  - Academic Risk Tier: **Low Risk (Green)**, **Moderate Risk (Amber)**, **High Risk (Red)**.
  - Actionable recommendation for faculty mentors (e.g., *"Schedule remedial sessions on Topic 3: Dynamic Programming"*).
- **Why this algorithm**: Proactive early-warning system. Ensures no student falls through the cracks before semester exams.

---

### Module 5: Context-Aware AI Assistant & Speech NLP
- **Algorithm**: **Retrieval-Augmented Generation (RAG) + Dynamic Context Injection**.
- **How it works**:
  1. User speaks or types: *"What is my next lecture?"* or *"Draft a quiz question on B-Trees for CO3 at Bloom Level 3"*.
  2. The backend extracts the logged-in teacher's identity, queries the active published timetable and syllabus database, and constructs an augmented prompt.
  3. The prompt is streamed to Groq LLaMA-3, which responds with zero hallucinations.
  4. Optional: ElevenLabs neural model synthesizes lifelike spoken audio response.
- **Why this algorithm**: General AI assistants (like ChatGPT) know nothing about your college's schedule or syllabus. ENOSIS injects live relational data so the assistant gives institutional-specific answers.

---

## 5. Technical Terms Glossary (Impress Your Examiners)

| Term | What It Means in ENOSIS |
| :--- | :--- |
| **NP-Hard Combinatorial Problem** | A class of computational problems (like the Traveling Salesperson or Timetable Scheduling) where finding an exact solution by checking all combinations takes exponential time. |
| **CP-SAT (Constraint Programming & Satisfiability)** | A solver technology that combines mathematical constraint rules with high-speed Boolean Logic (TRUE/FALSE) deduction. |
| **CDCL (Conflict-Driven Clause Learning)** | An optimization technique where a solver learns from failed branches and automatically prunes millions of invalid combinations. |
| **OBE (Outcome-Based Education)** | An educational philosophy mandated by NBA/NAAC where curriculum success is measured by verified student competencies (COs and POs) rather than credit hours. |
| **Bloom's Taxonomy** | A pedagogical framework classifying learning into 6 hierarchical cognitive levels: Remember, Understand, Apply, Analyze, Evaluate, Create. |
| **Longitudinal Assessment** | Tracking the same cohort of students across multiple time horizons (PRE $\rightarrow$ MID $\rightarrow$ END) to measure actual growth over time. |
| **RBAC (Role-Based Access Control)** | Security pattern restricting system capabilities based on assigned role: Administrator, Timetable Coordinator, or Faculty Member. |
| **JWT (JSON Web Token)** | Cryptographically signed, stateless authentication tokens exchanged between Flutter client and FastAPI backend. |
| **ACID Transactions** | Atomicity, Consistency, Isolation, Durability — database guarantees ensuring that publishing a timetable either completely succeeds or rolls back safely. |
| **RAG (Retrieval-Augmented Generation)** | Enhancing an AI model with institutional facts fetched in real time from a database before generating responses. |

---

## 6. Top Viva Questions & Model Answers Across All Modules

### **Q1: What is the overarching architecture of ENOSIS?**
> **Answer**:  
> "ENOSIS is designed as a **decoupled, 3-tier microservices architecture**:
> 1. **Client Tier**: A cross-platform **Flutter** application with reactive Provider state management and local SharedPreferences caching.
> 2. **Application Tier**: A high-performance **FastAPI** backend in Python providing asynchronous REST APIs, JWT authentication, and the Google OR-Tools optimization engine.
> 3. **Persistence Tier**: A containerized **MySQL 8.0** relational database for ACID-compliant academic data, complemented by Cloudinary for document assets.
> The entire stack is orchestrated using **Docker Compose** for reproducible deployment."

### **Q2: Why did you choose Google OR-Tools CP-SAT over Genetic Algorithms or Machine Learning for the timetable?**
> **Answer**:  
> "Timetable generation is an NP-Hard combinatorial optimization problem. Machine Learning produces probabilistic guesses (e.g. 95% likelihood), which means it can leave accidental clashes. Genetic Algorithms rely on random crossover and mutation, frequently getting trapped in local optima and failing hard constraints.  
> **Google OR-Tools CP-SAT is deterministic and exact**. It uses Conflict-Driven Clause Learning (CDCL) to guarantee **100% satisfaction of all hard rules** (zero teacher double-booking, continuous 2-hour lab blocks, room limits) while optimizing soft preferences in just 2 to 5 seconds."

### **Q3: How does the system handle parallel lab batches?**
> **Answer**:  
> "In college departments, a class divides into Batch 1 and Batch 2 during practical hours. Our solver enforces that a single teacher can never teach two batches simultaneously. It synchronizes both batches in the same 2-hour time window, but schedules **different subjects with different faculty members across separate laboratories** (for example, Batch 1 does Python Lab with Teacher A in Lab 1, while Batch 2 does Web Lab with Teacher B in Lab 2). This accurately mirrors real-world academic scheduling."

### **Q4: How does ENOSIS help a college during an NBA or NAAC accreditation visit?**
> **Answer**:  
> "Under NBA and NAAC Criterion 2, institutions must prove Outcome-Based Education (OBE) through Course Outcome (CO) and Program Outcome (PO) attainment. Normally, faculty spend weeks manually compiling internal exam marks and exit surveys into Excel sheets.  
> ENOSIS automatically calculates **Direct Attainment** from assessments and **Indirect Attainment** from surveys, performs the matrix dot-product mapping against PO1–PO12 and PSOs, and exports audit-ready, pre-formatted accreditation Excel spreadsheets with a single click."

### **Q5: What is the purpose of the 3-stage SLI (Student Learning Intelligence) module?**
> **Answer**:  
> "Traditional college exams are purely summative—teachers only know a student failed after the semester ends. SLI introduces a 3-stage framework:
> 1. **PRE**: Evaluates baseline knowledge and prerequisites before teaching begins.
> 2. **MID**: Measures conceptual comprehension mid-semester, automatically flagging learning bottlenecks and generating teacher intervention logs.
> 3. **END**: Measures comprehensive mastery and feeds directly into CO-PO calculations.
> This transforms assessment from passive grading into proactive learning intelligence."

### **Q6: How does the AI Assistant avoid hallucinations when asked college-specific questions?**
> **Answer**:  
> "We implement **Retrieval-Augmented Generation (RAG)** with Dynamic Context Injection. When a faculty member asks a question, the backend first queries the MySQL database for that specific teacher's profile, assigned subjects, and active published timetable. This factual data is injected into the prompt sent to the LLM (Groq LLaMA-3), ensuring the AI answers strictly using institutional facts rather than guessing."

### **Q7: What happens if an administrator publishes a timetable? How do teachers see it?**
> **Answer**:  
> "When the administrator publishes a timetable via `POST /timetable/publish`, the exact solved grid is stored as an immutable snapshot in `GenerationRun.config_snapshot` and normalized into individual `TimetableEntry` records.  
> All faculty members access the timetable via `GET /timetable/published`. The Flutter client caches this snapshot in `SharedPreferences` and automatically projects the data into 4 distinct views: **Class Views**, **Faculty Views**, **Labs**, and **Classrooms**."

---

## 7. Quick Summary Card for Presentation Slides

- **Project Name**: ENOSIS (*Every Task. One Solution.*)
- **Domain**: Higher Education Academic ERP, Accreditation Automation & Operations Research
- **Frontend**: Flutter 3.x (Web / Desktop / Mobile) with Provider State Management
- **Backend**: FastAPI (Python 3.12) with SQLAlchemy ORM
- **Optimization Engine**: Google OR-Tools CP-SAT Solver (NP-Hard Combinatorial Problem)
- **Database**: MySQL 8.0 (Dockerized) + LocalStorage Caching
- **Accreditation Compliance**: NBA / NAAC Outcome-Based Education (CO-PO Mapping)
- **Key Modules**: 
  1. Intelligent Timetable Optimizer
  2. CO-PO Attainment Matrix Engine
  3. Student Learning Intelligence (PRE $\rightarrow$ MID $\rightarrow$ END)
  4. Academic Risk & Retention Predictor
  5. Faculty Command Center & Daily Workload Hub
  6. PBAS Career Advancement Dossier
  7. Smart Academic Task Planner
  8. Context-Aware Institutional AI Assistant
