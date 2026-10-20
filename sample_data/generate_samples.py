import csv
import os

students = [
    ("1", "24AIML001", "Aarav Sharma", "20240101"),
    ("2", "24AIML002", "Aditi Patel", "20240102"),
    ("3", "24AIML003", "Ananya Iyer", "20240103"),
    ("4", "24AIML004", "Aryan Verma", "20240104"),
    ("5", "24AIML005", "Bhavya Deshmukh", "20240105"),
    ("6", "24AIML006", "Chaitanya Kulkarni", "20240106"),
    ("7", "24AIML007", "Devika Nair", "20240107"),
    ("8", "24AIML008", "Divyansh Joshi", "20240108"),
    ("9", "24AIML009", "Esha Rao", "20240109"),
    ("10", "24AIML010", "Gaurav Shinde", "20240110"),
    ("11", "24AIML011", "Harsh Vardhan", "20240111"),
    ("12", "24AIML012", "Ishita Sengupta", "20240112"),
    ("13", "24AIML013", "Kabir Mehta", "20240113"),
    ("14", "24AIML014", "Kavya Nambiar", "20240114"),
    ("15", "24AIML015", "Manish Choudhary", "20240115"),
    ("16", "24AIML016", "Meera Pillai", "20240116"),
    ("17", "24AIML017", "Nikhil Sawant", "20240117"),
    ("18", "24AIML018", "Pooja Hegde", "20240118"),
    ("19", "24AIML019", "Pranav Kadam", "20240119"),
    ("20", "24AIML020", "Rhea Mukherjee", "20240120"),
    ("21", "24AIML021", "Rohan Gupta", "20240121"),
    ("22", "24AIML022", "Sakshi Gaikwad", "20240122"),
    ("23", "24AIML023", "Sameer Khan", "20240123"),
    ("24", "24AIML024", "Sanjana Bhat", "20240124"),
    ("25", "24AIML025", "Siddharth Jain", "20240125"),
    ("26", "24AIML026", "Sneha Roy", "20240126"),
    ("27", "24AIML027", "Tanvi Agarwal", "20240127"),
    ("28", "24AIML028", "Utkarsh Mishra", "20240128"),
    ("29", "24AIML029", "Varun Patil", "20240129"),
    ("30", "24AIML030", "Zoya Ansari", "20240130")
]

out_dir = r"d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\sample_data"
os.makedirs(out_dir, exist_ok=True)

# 1. Student List (Roll Call)
with open(os.path.join(out_dir, "1_Student_List_Roll_Call.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Sr.No", "Roll No", "Student Name", "PRN"])
    for s in students:
        writer.writerow(s)

# 2. ISE 1 Marks
ise1_marks = [8.5, 7.0, 9.0, 6.5, 8.0, 5.5, 7.5, 9.5, 6.0, 8.0, 7.5, 8.5, 6.5, 9.0, 5.0, 8.0, 7.0, 8.5, 6.0, 9.5, 8.0, 7.5, 6.5, 9.0, 8.5, 7.0, 8.0, 6.0, 7.5, 9.0]
with open(os.path.join(out_dir, "2_ISE_1_Marks.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Roll No", "Student Name", "Marks (Out of 10)"])
    for i, s in enumerate(students):
        writer.writerow([s[1], s[2], ise1_marks[i]])

# 3. ISE 2 Marks
ise2_marks = [9.0, 8.0, 9.5, 7.0, 8.5, 6.5, 8.0, 10.0, 7.0, 8.5, 8.0, 9.0, 7.5, 9.5, 6.0, 8.5, 7.5, 9.0, 7.0, 10.0, 8.5, 8.0, 7.0, 9.5, 9.0, 7.5, 8.5, 7.0, 8.0, 9.5]
with open(os.path.join(out_dir, "3_ISE_2_Marks.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Roll No", "Student Name", "Marks (Out of 10)"])
    for i, s in enumerate(students):
        writer.writerow([s[1], s[2], ise2_marks[i]])

# 4. MSE Marks (Q1-Q4)
with open(os.path.join(out_dir, "4_MSE_Marks.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Roll No", "Student Name", "Q1 (5)", "Q2 (5)", "Q3 (10)", "Q4 (10)"])
    for i, s in enumerate(students):
        q1 = round(3.5 + (i % 4) * 0.5, 1)
        q2 = round(3.0 + ((i + 1) % 4) * 0.5, 1)
        q3 = round(7.0 + ((i + 2) % 6) * 0.5, 1)
        q4 = round(7.5 + ((i + 3) % 5) * 0.5, 1)
        writer.writerow([s[1], s[2], q1, q2, q3, q4])

# 5. ESE Marks (Q1-Q6)
with open(os.path.join(out_dir, "5_ESE_Marks.csv"), "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Roll No", "Student Name", "Q1 (10)", "Q2 (10)", "Q3 (10)", "Q4 (10)", "Q5 (10)", "Q6 (10)"])
    for i, s in enumerate(students):
        q1 = round(7.0 + (i % 5) * 0.6, 1)
        q2 = round(6.5 + ((i + 1) % 5) * 0.7, 1)
        q3 = round(7.5 + ((i + 2) % 4) * 0.6, 1)
        q4 = round(6.0 + ((i + 3) % 6) * 0.6, 1)
        q5 = round(8.0 + ((i + 4) % 4) * 0.5, 1)
        q6 = round(7.0 + ((i + 1) % 5) * 0.5, 1)
        writer.writerow([s[1], s[2], q1, q2, q3, q4, q5, q6])

print("CSV sample files generated successfully!")
