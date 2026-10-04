"""
ENOSIS Email Service
====================
Sends onboarding and password-reset emails to faculty via SMTP.
Falls back to console logging when SMTP is not configured (dev mode).
"""

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings

logger = logging.getLogger(__name__)


# ─── SMTP transport ──────────────────────────────────────────────────────────

def _smtp_configured() -> bool:
    return bool(settings.SMTP_HOST and settings.SMTP_USER and settings.SMTP_PASSWORD)


def _send_smtp(to_email: str, subject: str, body_text: str) -> bool:
    """Send a plain-text email via the configured SMTP relay."""
    sender = settings.ADMIN_EMAIL or settings.SMTP_USER
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"ENOSIS <{sender}>"
    msg["To"] = to_email
    msg.attach(MIMEText(body_text, "plain", "utf-8"))

    try:
        if settings.SMTP_USE_TLS:
            server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15)
            server.ehlo()
            server.starttls()
            server.ehlo()
        else:
            server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15)
            server.ehlo()

        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.sendmail(sender, [to_email], msg.as_string())
        server.quit()
        logger.info("Email sent to %s (%s)", to_email, subject)
        return True
    except Exception as exc:
        logger.error("SMTP send failed for %s: %s", to_email, exc)
        return False


def _console_fallback(to_email: str, subject: str, body_text: str) -> bool:
    """Log the email to the server console — used when SMTP is not configured."""
    logger.warning(
        "\n╔══════════════════ EMAIL (console fallback) ══════════════════╗"
        "\n║ To:      %s"
        "\n║ Subject: %s"
        "\n╟──────────────────────────────────────────────────────────────╢"
        "\n%s"
        "\n╚══════════════════════════════════════════════════════════════╝",
        to_email, subject, body_text,
    )
    return True  # Always "succeeds" — it's for dev convenience


# ─── Public API ──────────────────────────────────────────────────────────────

def send_email(to_email: str, subject: str, body_text: str) -> bool:
    """
    Dispatch an email. Uses SMTP when configured, otherwise prints to console.
    Returns True if the message was delivered (or logged) successfully.
    """
    if _smtp_configured():
        return _send_smtp(to_email, subject, body_text)
    return _console_fallback(to_email, subject, body_text)


def send_onboarding_email(faculty_name: str, faculty_email: str, password: str) -> bool:
    """Send the welcome / credential email after faculty account creation."""
    subject = "Welcome to ENOSIS — Your Account Credentials"
    body = (
        f"Dear {faculty_name},\n"
        f"\n"
        f"Welcome to ENOSIS.\n"
        f"\n"
        f"Your faculty account has been created successfully. "
        f"Please use the credentials provided below to access the platform:\n"
        f"\n"
        f"Email ID: {faculty_email}\n"
        f"Password: {password}\n"
        f"\n"
        f"Portal Link: (will be updated soon)\n"
        f"\n"
        f"For security reasons, please change your password after your first login.\n"
        f"\n"
        f"If you face any issues while logging in, please contact the administrator.\n"
        f"\n"
        f"Regards,\n"
        f"Team ENOSIS"
    )
    return send_email(faculty_email, subject, body)


def send_password_reset_email(faculty_email: str, temporary_password: str) -> bool:
    """Send a password-reset email with a new temporary password."""
    subject = "Password Reset — ENOSIS"
    body = (
        f"Password Reset\n"
        f"Hello ENOSIS Member,\n"
        f"\n"
        f"Your temporary password is: {temporary_password}\n"
        f"\n"
        f"Please log in and change this password immediately "
        f"via your Edit Password menu.\n"
        f"\n"
        f"\n"
        f"Best Regards,\n"
        f"ENOSIS Team"
    )
    return send_email(faculty_email, subject, body)
