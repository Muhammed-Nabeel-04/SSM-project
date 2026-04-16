# SSM System - Application Testing Guide

Welcome to the **Student Success Matrix (SSM)** application. This guide will walk you through the complete end-to-end flow of the system.

*(Note: Ensure the backend is running and the mobile app is correctly pointing to the production URL.)*

---

## 1. Initial Setup (Admin Flow)
The first step is to set up the institution's structure and users.

1. **Log in as Admin** (Staff/Admin Tab):
   - **Email:** `admin@college.edu`
   - **Password:** `Admin@1234`
2. **Create a Department:**
   - In the Admin Dashboard, tap on **Departments** (Quick Actions).
   - Add a new department (e.g., Name: `Computer Science`, Code: `CSE`).
3. **Create Users:**
   - Go back and tap on **User Management** -> **Add New User** (or use the '+' button).
   - **Create a Mentor:**
     - Select Role: `Mentor`
     - Fill in their Email, Name, Department, and assign a Password.
   - **Create a Student:**
     - Select Role: `Student`
     - Provide their Register Number (e.g., `REG001`), Name, Email, Department, and assign them to the Mentor you just created. Set a Password.
   - *(Optional)* Create an `HOD` for the department.

---

## 2. Student Activity & Form Submission (Student Flow)
Now, test the application from a student's perspective.

1. **Log out** of the Admin account.
2. **Log in as Student** (Student Tab):
   - **Register Number:** (the one you just created, e.g., `REG001`)
   - **Password:** (the password you assigned)
3. **Add Activities / Achievements:**
   - Go to the **Activities** section (bottom navigation).
   - Tap '+' to add a new activity. You can upload an image of a certificate (our built-in OCR will attempt to read details automatically!).
4. **Submit the SSM Form:**
   - Go to the **Form** tab.
   - Fill out the self-evaluation scores across different categories (Academic, Skills, Discipline, etc.).
   - Tap **Submit to Mentor** when finished.

---

## 3. Mentor Review (Mentor Flow)
The mentor must review the student's claims and rate their soft skills/discipline.

1. **Log out** of the Student account.
2. **Log in as Mentor** (Staff/Admin Tab):
   - **Email:** (the mentor's email you created)
   - **Password:** (the mentor's password)
3. **Review Pending Forms:**
   - On the Mentor Dashboard, you will see the student's submitted form under "Pending Reviews".
   - Tap on the student's form.
4. **Evaluate & Forward:**
   - Review the activities and documents the student uploaded.
   - Provide Mentor ratings (e.g., Technical Skills, Dress Code, Leadership).
   - Add your remarks and tap **Submit to HOD** (or Reject if corrections are needed).

---

## 4. Final Approval (HOD / Admin Flow)
The final step is the Head of Department confirming the score.

1. **Log out** of the Mentor account.
2. **Log in as HOD** (if created) or use the **Admin** account.
3. **Approve Form:**
   - Locate the student's form in the HOD Dashboard.
   - Review all data, add final remarks, and tap **Approve**.
4. **Analytics Check:**
   - Log back into the **Admin** account.
   - On the Admin Dashboard, under **Analytics Overview**, you will now see the Approved form.
   - Scroll down to **Top Students** to see the student's final calculated points and Star Rating!

---
**🎉 End of Test Flow.** This demonstrates the complete lifecycle of the SSM ecosystem.
