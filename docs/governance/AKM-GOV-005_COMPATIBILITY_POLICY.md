# AKM-GOV-005

# Akmena Compatibility Policy

Version: 1.0

Status: Normative

Authority: Governance

---

# Purpose

This document defines compatibility requirements between protocol versions and independent implementations.

---

# Backward Compatibility

Backward compatibility SHOULD be preserved whenever practical.

Breaking compatibility requires a Major protocol version.

---

# Forward Compatibility

Protocol objects SHOULD ignore unknown optional fields whenever possible.

---

# Specification Compatibility

Reference implementations SHALL identify the Specification version they implement.

---

# Standards Compatibility

Implementations SHALL identify supported APS versions.

---

# RFC Compatibility

Implementations SHALL serialize protocol objects according to the RFC versions they support.

---

# Implementation Independence

Compatibility SHALL be determined by protocol behavior rather than programming language or platform.

---

# Unsupported Versions

Implementations MAY discontinue support for obsolete versions after public notice.

---

# Compatibility Matrix

Every production implementation SHALL publish a compatibility matrix identifying supported protocol versions.

---

# Amendment

Changes to compatibility policy require Governance approval.
