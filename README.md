# 🚀 MVI (Model–View–Intent) Architecture

A unidirectional data flow architecture used to build predictable and scalable iOS applications.

## 🧩 Components

* **Model (State)**
  Represents the UI state. It is a single source of truth and drives what the view renders.

* **View**
  Displays the UI based on the current state and sends user actions.

* **Intent**
  Represents user actions or events (e.g., button tap, screen load).

* **Reducer**
  Processes intents and updates the state accordingly.

---

## 🔁 Flow

Intent → Reducer → State → View → Intent

---

## ✨ Key Characteristics

* Unidirectional data flow
* Clear separation of concerns
* Predictable state management
* Easy debugging and testing

---

## 📱 Usage

* View sends **Intent**
* Reducer handles logic (API call / processing)
* Updates **State**
* View re-renders automatically

---

## 💡 Takeaway

MVI ensures a **single source of truth** and makes UI behavior predictable, especially for complex screens.
