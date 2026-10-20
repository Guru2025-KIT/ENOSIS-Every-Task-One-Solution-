$students = @(
    @("1", "24AIML001", "Aarav Sharma", "20240101"),
    @("2", "24AIML002", "Aditi Patel", "20240102"),
    @("3", "24AIML003", "Ananya Iyer", "20240103"),
    @("4", "24AIML004", "Aryan Verma", "20240104"),
    @("5", "24AIML005", "Bhavya Deshmukh", "20240105"),
    @("6", "24AIML006", "Chaitanya Kulkarni", "20240106"),
    @("7", "24AIML007", "Devika Nair", "20240107"),
    @("8", "24AIML008", "Divyansh Joshi", "20240108"),
    @("9", "24AIML009", "Esha Rao", "20240109"),
    @("10", "24AIML010", "Gaurav Shinde", "20240110"),
    @("11", "24AIML011", "Harsh Vardhan", "20240111"),
    @("12", "24AIML012", "Ishita Sengupta", "20240112"),
    @("13", "24AIML013", "Kabir Mehta", "20240113"),
    @("14", "24AIML014", "Kavya Nambiar", "20240114"),
    @("15", "24AIML015", "Manish Choudhary", "20240115"),
    @("16", "24AIML016", "Meera Pillai", "20240116"),
    @("17", "24AIML017", "Nikhil Sawant", "20240117"),
    @("18", "24AIML018", "Pooja Hegde", "20240118"),
    @("19", "24AIML019", "Pranav Kadam", "20240119"),
    @("20", "24AIML020", "Rhea Mukherjee", "20240120"),
    @("21", "24AIML021", "Rohan Gupta", "20240121"),
    @("22", "24AIML022", "Sakshi Gaikwad", "20240122"),
    @("23", "24AIML023", "Sameer Khan", "20240123"),
    @("24", "24AIML024", "Sanjana Bhat", "20240124"),
    @("25", "24AIML025", "Siddharth Jain", "20240125"),
    @("26", "24AIML026", "Sneha Roy", "20240126"),
    @("27", "24AIML027", "Tanvi Agarwal", "20240127"),
    @("28", "24AIML028", "Utkarsh Mishra", "20240128"),
    @("29", "24AIML029", "Varun Patil", "20240129"),
    @("30", "24AIML030", "Zoya Ansari", "20240130")
)

$outDir = "d:\DevSpace\ENOSIS\ENOSIS-Every-Task-One-Solution-\sample_data"

# 1. Student List (Roll Call)
$file1 = Join-Path $outDir "1_Student_List_Roll_Call.csv"
$lines1 = @("Sr.No,Roll No,Student Name,PRN")
foreach ($s in $students) {
    $lines1 += "$($s[0]),$($s[1]),$($s[2]),$($s[3])"
}
$lines1 | Set-Content -Path $file1 -Encoding UTF8

# 2. ISE 1 Marks
$file2 = Join-Path $outDir "2_ISE_1_Marks.csv"
$ise1 = @(8.5, 7.0, 9.0, 6.5, 8.0, 5.5, 7.5, 9.5, 6.0, 8.0, 7.5, 8.5, 6.5, 9.0, 5.0, 8.0, 7.0, 8.5, 6.0, 9.5, 8.0, 7.5, 6.5, 9.0, 8.5, 7.0, 8.0, 6.0, 7.5, 9.0)
$lines2 = @("Roll No,Student Name,Marks (Out of 10)")
for ($i = 0; $i -lt $students.Count; $i++) {
    $lines2 += "$($students[$i][1]),$($students[$i][2]),$($ise1[$i])"
}
$lines2 | Set-Content -Path $file2 -Encoding UTF8

# 3. ISE 2 Marks
$file3 = Join-Path $outDir "3_ISE_2_Marks.csv"
$ise2 = @(9.0, 8.0, 9.5, 7.0, 8.5, 6.5, 8.0, 10.0, 7.0, 8.5, 8.0, 9.0, 7.5, 9.5, 6.0, 8.5, 7.5, 9.0, 7.0, 10.0, 8.5, 8.0, 7.0, 9.5, 9.0, 7.5, 8.5, 7.0, 8.0, 9.5)
$lines3 = @("Roll No,Student Name,Marks (Out of 10)")
for ($i = 0; $i -lt $students.Count; $i++) {
    $lines3 += "$($students[$i][1]),$($students[$i][2]),$($ise2[$i])"
}
$lines3 | Set-Content -Path $file3 -Encoding UTF8

# 4. MSE Marks (Q1-Q4)
$file4 = Join-Path $outDir "4_MSE_Marks.csv"
$lines4 = @("Roll No,Student Name,Q1 (5),Q2 (5),Q3 (10),Q4 (10)")
for ($i = 0; $i -lt $students.Count; $i++) {
    $q1 = [math]::Round(3.5 + ($i % 4) * 0.5, 1)
    $q2 = [math]::Round(3.0 + (($i + 1) % 4) * 0.5, 1)
    $q3 = [math]::Round(7.0 + (($i + 2) % 6) * 0.5, 1)
    $q4 = [math]::Round(7.5 + (($i + 3) % 5) * 0.5, 1)
    $lines4 += "$($students[$i][1]),$($students[$i][2]),$q1,$q2,$q3,$q4"
}
$lines4 | Set-Content -Path $file4 -Encoding UTF8

# 5. ESE Marks (Q1-Q6)
$file5 = Join-Path $outDir "5_ESE_Marks.csv"
$lines5 = @("Roll No,Student Name,Q1 (10),Q2 (10),Q3 (10),Q4 (10),Q5 (10),Q6 (10)")
for ($i = 0; $i -lt $students.Count; $i++) {
    $q1 = [math]::Round(7.0 + ($i % 5) * 0.6, 1)
    $q2 = [math]::Round(6.5 + (($i + 1) % 5) * 0.7, 1)
    $q3 = [math]::Round(7.5 + (($i + 2) % 4) * 0.6, 1)
    $q4 = [math]::Round(6.0 + (($i + 3) % 6) * 0.6, 1)
    $q5 = [math]::Round(8.0 + (($i + 4) % 4) * 0.5, 1)
    $q6 = [math]::Round(7.0 + (($i + 1) % 5) * 0.5, 1)
    $lines5 += "$($students[$i][1]),$($students[$i][2]),$q1,$q2,$q3,$q4,$q5,$q6"
}
$lines5 | Set-Content -Path $file5 -Encoding UTF8

Write-Host "All 5 demo sheets created successfully in $outDir"
