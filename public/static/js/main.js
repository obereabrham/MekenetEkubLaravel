/* ==========================================
   MEKENET EKUB
   MAIN JAVASCRIPT
   ========================================== */


document.addEventListener(
    "DOMContentLoaded",
    function () {

        initializeAuthModal();

        initializeCounters();

    }
);


/* ==========================================
   THEME
   ========================================== */

/* ==========================================
   AUTH MODAL
   ========================================== */

function initializeAuthModal() {

    const modal =
        document.getElementById(
            "authModal"
        );

    if (!modal) {
        return;
    }


    const loginButton =
        document.getElementById(
            "loginButton"
        );

    const registerButton =
        document.getElementById(
            "registerButton"
        );

    const heroRegisterButton =
        document.getElementById(
            "heroRegisterButton"
        );

    const ctaRegisterButton =
        document.getElementById(
            "ctaRegisterButton"
        );

    const closeButton =
        document.getElementById(
            "closeAuthModal"
        );

    const modalLoginButton =
        document.getElementById(
            "modalLoginButton"
        );

    const modalRegisterButton =
        document.getElementById(
            "modalRegisterButton"
        );


    function openModal() {

        modal.classList.add(
            "active"
        );

    }


    function closeModal() {

        modal.classList.remove(
            "active"
        );

    }


    if (loginButton) {

        loginButton.addEventListener(
            "click",
            openModal
        );

    }


    if (registerButton) {

    registerButton.addEventListener(
        "click",
        function () {

            window.location.href =
                "/register";

        }
    );

}


   if (heroRegisterButton) {

    heroRegisterButton.addEventListener(
        "click",
        function () {

            window.location.href =
                "/register";

        }
    );

}


    if (ctaRegisterButton) {

    ctaRegisterButton.addEventListener(
        "click",
        function () {

            window.location.href =
                "/register";

        }
    );

}


    if (closeButton) {

        closeButton.addEventListener(
            "click",
            closeModal
        );

    }


    if (modalLoginButton) {

        modalLoginButton.addEventListener(
            "click",
            function () {

                showToast(
                    "Sign In",
                    "The login page will be connected in Part 3."
                );

            }
        );

    }


    if (modalRegisterButton) {

        modalRegisterButton.addEventListener(
            "click",
            function () {

                showToast(
                    "Create Account",
                    "Registration will be connected in Part 2."
                );

            }
        );

    }


    modal.addEventListener(
        "click",
        function (event) {

            if (
                event.target === modal
            ) {

                closeModal();

            }

        }
    );

}


/* ==========================================
   COUNTERS
   ========================================== */

function initializeCounters() {

    const counters =
        document.querySelectorAll(
            ".counter"
        );


    counters.forEach(
        function (counter) {

            const target =
                Number(
                    counter.dataset.target
                ) || 0;

            animateCounter(
                counter,
                target
            );

        }
    );

}


function animateCounter(
    element,
    target
) {

    let current = 0;

    const duration = 1300;

    const start =
        performance.now();


    function update(
        currentTime
    ) {

        const elapsed =
            currentTime - start;

        const progress =
            Math.min(
                elapsed / duration,
                1
            );

        const eased =
            1 -
            Math.pow(
                1 - progress,
                3
            );

        current =
            Math.floor(
                target * eased
            );

        element.textContent =
            current.toLocaleString();


        if (progress < 1) {

            requestAnimationFrame(
                update
            );

        } else {

            element.textContent =
                target.toLocaleString();

        }

    }


    requestAnimationFrame(
        update
    );

}


/* ==========================================
   TOAST
   ========================================== */

function showToast(
    title,
    message
) {

    const toast =
        document.getElementById(
            "toast"
        );

    const titleElement =
        document.getElementById(
            "toastTitle"
        );

    const messageElement =
        document.getElementById(
            "toastMessage"
        );


    if (!toast) {
        return;
    }


    titleElement.textContent =
        title;

    messageElement.textContent =
        message;


    toast.classList.add(
        "show"
    );


    setTimeout(
        function () {

            toast.classList.remove(
                "show"
            );

        },
        3500
    );

}
/* ==========================================
   REGISTRATION
   ========================================== */

document.addEventListener(
    "DOMContentLoaded",
    function () {

        initializeRegistration();

    }
);


function initializeRegistration() {

    const form =
        document.getElementById(
            "registerForm"
        );

    if (!form) {
        return;
    }


    const phone =
        document.getElementById(
            "phone"
        );

    const password =
        document.getElementById(
            "password"
        );

    const confirmPassword =
        document.getElementById(
            "confirmPassword"
        );

    const termsButton =
        document.getElementById(
            "termsButton"
        );

    const termsModal =
        document.getElementById(
            "termsModal"
        );

    const closeTerms =
        document.getElementById(
            "closeTermsModal"
        );

    const agreeTerms =
        document.getElementById(
            "agreeTermsButton"
        );

    const terms =
        document.getElementById(
            "terms"
        );


    /* ======================================
       PHONE
       ====================================== */

    phone.addEventListener(
        "input",
        function () {

            this.value =
                this.value
                    .replace(
                        /\D/g,
                        ""
                    )
                    .slice(
                        0,
                        9
                    );

        }
    );


    /* ======================================
       PASSWORD REQUIREMENTS
       ====================================== */

    password.addEventListener(
        "input",
        function () {

            const value =
                this.value;


            updatePasswordRequirement(
                "reqLength",
                value.length >= 8
            );


            updatePasswordRequirement(
                "reqUpper",
                /[A-Z]/.test(value)
            );


            updatePasswordRequirement(
                "reqNumber",
                /[0-9]/.test(value)
            );


            updatePasswordRequirement(
                "reqSpecial",
                /[^A-Za-z0-9]/.test(value)
            );

        }
    );


    function updatePasswordRequirement(
        id,
        valid
    ) {

        const element =
            document.getElementById(id);

        if (!element) {
            return;
        }


        const icon =
            element.querySelector(
                "span"
            );


        if (valid) {

            element.classList.add(
                "valid"
            );

            icon.textContent = "✓";

        } else {

            element.classList.remove(
                "valid"
            );

            icon.textContent = "○";

        }

    }


    /* ======================================
       PASSWORD VISIBILITY
       ====================================== */

    document
        .querySelectorAll(
            ".password-toggle"
        )
        .forEach(
            function (button) {

                button.addEventListener(
                    "click",
                    function () {

                        const targetId =
                            this.dataset.target;

                        const target =
                            document.getElementById(
                                targetId
                            );


                        if (
                            target.type ===
                            "password"
                        ) {

                            target.type =
                                "text";

                            this.textContent =
                                "Hide";

                        } else {

                            target.type =
                                "password";

                            this.textContent =
                                "Show";

                        }

                    }
                );

            }
        );


    /* ======================================
       TERMS MODAL
       ====================================== */

    if (termsButton) {

        termsButton.addEventListener(
            "click",
            function () {

                termsModal.classList.add(
                    "active"
                );

            }
        );

    }


    if (closeTerms) {

        closeTerms.addEventListener(
            "click",
            function () {

                termsModal.classList.remove(
                    "active"
                );

            }
        );

    }


    if (agreeTerms) {

        agreeTerms.addEventListener(
            "click",
            function () {

                terms.checked = true;

                termsModal.classList.remove(
                    "active"
                );

            }
        );

    }


    /* ======================================
       CLICK OUTSIDE TERMS
       ====================================== */

    if (termsModal) {

        termsModal.addEventListener(
            "click",
            function (event) {

                if (
                    event.target ===
                    termsModal
                ) {

                    termsModal.classList.remove(
                        "active"
                    );

                }

            }
        );

    }


    /* ======================================
       CLIENT VALIDATION
       ====================================== */

    form.addEventListener(
        "submit",
        function (event) {

            let valid = true;


            const firstName =
                document.getElementById(
                    "firstName"
                );


            const lastName =
                document.getElementById(
                    "lastName"
                );


            const username =
                document.getElementById(
                    "username"
                );


            const email =
                document.getElementById(
                    "email"
                );


            const firstNameError =
                document.getElementById(
                    "firstNameError"
                );


            const lastNameError =
                document.getElementById(
                    "lastNameError"
                );


            const usernameError =
                document.getElementById(
                    "usernameError"
                );


            const phoneError =
                document.getElementById(
                    "phoneError"
                );


            const emailError =
                document.getElementById(
                    "emailError"
                );


            const confirmError =
                document.getElementById(
                    "confirmPasswordError"
                );


            const termsError =
                document.getElementById(
                    "termsError"
                );


            firstNameError.textContent =
                "";

            lastNameError.textContent =
                "";

            usernameError.textContent =
                "";

            phoneError.textContent =
                "";

            emailError.textContent =
                "";

            confirmError.textContent =
                "";

            termsError.textContent =
                "";


            if (
                !firstName.value.trim()
            ) {

                firstNameError.textContent =
                    "First name is required.";

                valid = false;

            }


            if (
                !lastName.value.trim()
            ) {

                lastNameError.textContent =
                    "Last name is required.";

                valid = false;

            }


            if (
                username.value.trim().length < 3
            ) {

                usernameError.textContent =
                    "Username must contain at least 3 characters.";

                valid = false;

            }


            if (
                !/^9\d{8}$/.test(
                    phone.value
                )
            ) {

                phoneError.textContent =
                    "Enter 9 digits beginning with 9.";

                valid = false;

            }


            if (
                email.value &&
                !/^[A-Za-z0-9._%+-]+@gmail\.com$/
                    .test(email.value)
            ) {

                emailError.textContent =
                    "Only valid @gmail.com addresses are accepted.";

                valid = false;

            }


            if (
                password.value.length < 8 ||
                !/[A-Z]/.test(password.value) ||
                !/[0-9]/.test(password.value) ||
                !/[^A-Za-z0-9]/.test(password.value)
            ) {

                valid = false;

            }


            if (
                password.value !==
                confirmPassword.value
            ) {

                confirmError.textContent =
                    "Passwords do not match.";

                valid = false;

            }


            if (!terms.checked) {

                termsError.textContent =
                    "You must agree to the Terms & Agreement.";

                valid = false;

            }


            if (!valid) {

                event.preventDefault();

                showToast(
                    "Check your information",
                    "Please correct the highlighted fields."
                );

            }

        }
    );

}
/* =====================================================
   MEKENET EKUB MAIN JAVASCRIPT
===================================================== */


/* =====================================================
   THEME
===================================================== */

function getPreferredTheme() {

    let saved = null;

    try {
        saved = localStorage.getItem("mekenet-theme");
    } catch (error) {}

    if (saved === "dark" || saved === "light") {
        return saved;
    }

    return (
        window.matchMedia &&
        window.matchMedia("(prefers-color-scheme: dark)").matches
    ) ? "dark" : "light";
}


function setTheme(theme) {

    const isDark = theme === "dark";

    document.body.classList.toggle("dark", isDark);
    document.body.classList.toggle("dark-mode", isDark);

    document.documentElement.setAttribute(
        "data-theme",
        isDark ? "dark" : "light"
    );

    document.documentElement.style.colorScheme =
        isDark ? "dark" : "light";

    document.documentElement.style.backgroundColor =
        isDark ? "#071411" : "#f4f8f6";

    const themeIcon =
        document.getElementById("themeIcon");

    if (themeIcon) {
        themeIcon.textContent = isDark ? "☀" : "☾";
    }

    const themeButton =
        document.querySelector(".theme-button");

    if (themeButton) {
        themeButton.setAttribute(
            "aria-pressed",
            isDark ? "true" : "false"
        );

        themeButton.title = isDark
            ? "Switch to light theme"
            : "Switch to dark theme";
    }
}


function applyTheme() {
    setTheme(getPreferredTheme());
}


function toggleTheme() {

    const next =
        document.body.classList.contains("dark-mode")
            ? "light"
            : "dark";

    try {
        localStorage.setItem("mekenet-theme", next);
    } catch (error) {}

    setTheme(next);
}


/* Apply immediately (script is loaded at the end of <body>) */
applyTheme();

document.addEventListener(
    "DOMContentLoaded",
    applyTheme
);


/* Keep every open tab in sync */
window.addEventListener("storage", function (event) {
    if (event.key === "mekenet-theme") {
        applyTheme();
    }
});


/* Follow the device setting until the user picks a theme manually */
if (window.matchMedia) {

    const media =
        window.matchMedia("(prefers-color-scheme: dark)");

    const onSystemChange = function () {

        let saved = null;

        try {
            saved = localStorage.getItem("mekenet-theme");
        } catch (error) {}

        if (!saved) {
            applyTheme();
        }
    };

    if (media.addEventListener) {
        media.addEventListener("change", onSystemChange);
    } else if (media.addListener) {
        media.addListener(onSystemChange);
    }
}


/* =====================================================
   PASSWORD VISIBILITY
===================================================== */

function togglePassword(
    inputId,
    button
) {

    const input =
        document.getElementById(inputId);


    if (!input) {
        return;
    }


    if (input.type === "password") {

        input.type = "text";

        button.textContent =
            "Hide";

    } else {

        input.type = "password";

        button.textContent =
            "Show";
    }
}


/* =====================================================
   MODALS
===================================================== */

function openModal(id) {

    const modal =
        document.getElementById(id);


    if (!modal) {
        return;
    }


    modal.classList.add("active");

    document.body.style.overflow =
        "hidden";
}


function closeModal(id) {

    const modal =
        document.getElementById(id);


    if (!modal) {
        return;
    }


    modal.classList.remove("active");

    document.body.style.overflow =
        "";
}


function acceptTerms() {

    const checkbox =
        document.getElementById("terms");


    if (checkbox) {

        checkbox.checked = true;
    }


    closeModal("termsModal");
}


/* =====================================================
   CLOSE MODAL WHEN CLICKING OUTSIDE
===================================================== */

document.addEventListener(
    "click",
    function(event) {

        if (
            event.target.classList.contains(
                "modal-overlay"
            )
        ) {

            event.target.classList.remove(
                "active"
            );

            document.body.style.overflow =
                "";
        }
    }
);


/* =====================================================
   FLASH MESSAGES
===================================================== */

function closeFlash(button) {

    const flash =
        button.closest(
            ".flash-message"
        );


    if (!flash) {
        return;
    }


    flash.style.opacity = "0";

    flash.style.transform =
        "translateX(30px)";


    setTimeout(
        function() {

            flash.remove();

        },
        300
    );
}


document.addEventListener(
    "DOMContentLoaded",
    function() {

        setTimeout(
            function() {

                const flashes =
                    document.querySelectorAll(
                        ".flash-message"
                    );


                flashes.forEach(
                    function(flash) {

                        flash.style.opacity =
                            "0";

                        flash.style.transform =
                            "translateX(30px)";

                        setTimeout(
                            function() {
                                flash.remove();
                            },
                            300
                        );

                    }
                );

            },
            7000
        );
    }
);


/* =====================================================
   PASSWORD VALIDATION UI
===================================================== */

function updatePasswordRules() {

    const password =
        document.getElementById(
            "password"
        );


    if (!password) {
        return;
    }


    const value =
        password.value;


    updateRule(
        "ruleLength",
        value.length >= 8
    );


    updateRule(
        "ruleUpper",
        /[A-Z]/.test(value)
    );


    updateRule(
        "ruleNumber",
        /[0-9]/.test(value)
    );


    updateRule(
        "ruleSpecial",
        /[^A-Za-z0-9]/.test(value)
    );
}


function updateRule(
    id,
    valid
) {

    const rule =
        document.getElementById(id);


    if (!rule) {
        return;
    }


    if (valid) {

        rule.classList.add("valid");

        rule.querySelector(
            "span"
        ).textContent = "✓";

    } else {

        rule.classList.remove("valid");

        rule.querySelector(
            "span"
        ).textContent = "○";
    }
}


document.addEventListener(
    "DOMContentLoaded",
    function() {

        const password =
            document.getElementById(
                "password"
            );


        if (password) {

            password.addEventListener(
                "input",
                updatePasswordRules
            );
        }
    }
);


/* =====================================================
   PHONE INPUT
===================================================== */

document.addEventListener(
    "DOMContentLoaded",
    function() {

        const phone =
            document.getElementById(
                "phone"
            );


        if (!phone) {
            return;
        }


        phone.addEventListener(
            "input",
            function() {

                let value =
                    this.value.replace(
                        /\D/g,
                        ""
                    );


                if (
                    value.length > 0 &&
                    value.charAt(0) !== "9"
                ) {

                    value = "";
                }


                this.value =
                    value.substring(
                        0,
                        9
                    );
            }
        );
    }
);


/* =====================================================
   REGISTER FORM
===================================================== */

document.addEventListener(
    "DOMContentLoaded",
    function() {

        const form =
            document.getElementById(
                "registerForm"
            );


        if (!form) {
            return;
        }


        form.addEventListener(
            "submit",
            function(event) {

                const password =
                    document.getElementById(
                        "password"
                    );


                const confirmPassword =
                    document.getElementById(
                        "confirm_password"
                    );


                const terms =
                    document.getElementById(
                        "terms"
                    );


                if (
                    !password ||
                    !confirmPassword ||
                    !terms
                ) {

                    return;
                }


                const validPassword =
                    password.value.length >= 8 &&
                    /[A-Z]/.test(password.value) &&
                    /[a-z]/.test(password.value) &&
                    /[0-9]/.test(password.value) &&
                    /[^A-Za-z0-9]/.test(password.value);


                if (!validPassword) {

                    event.preventDefault();

                    showClientMessage(
                        "Please complete all password requirements."
                    );

                    return;
                }


                if (
                    password.value !==
                    confirmPassword.value
                ) {

                    event.preventDefault();

                    showClientMessage(
                        "Passwords do not match."
                    );

                    return;
                }


                if (!terms.checked) {

                    event.preventDefault();

                    showClientMessage(
                        "You must agree to the Terms & Agreement."
                    );
                }

            }
        );
    }
);


/* =====================================================
   CLIENT MESSAGE
===================================================== */

function showClientMessage(message) {

    let container =
        document.getElementById(
            "clientMessage"
        );


    if (!container) {

        container =
            document.createElement(
                "div"
            );

        container.id =
            "clientMessage";

        container.className =
            "flash-container";

        document.body.appendChild(
            container
        );
    }


    MK.alert(message, "error");
}


/* =====================================================
   COMING SOON
===================================================== */

function showComingSoon(event) {

    if (event) {
        event.preventDefault();
    }


    showClientMessage(
        "Password recovery is not enabled in this version."
    );
}


/* =====================================================
   KEYBOARD ESCAPE
===================================================== */

document.addEventListener(
    "keydown",
    function(event) {

        if (event.key !== "Escape") {
            return;
        }


        document
            .querySelectorAll(
                ".modal-overlay.active"
            )
            .forEach(
                function(modal) {

                    modal.classList.remove(
                        "active"
                    );
                }
            );


        document.body.style.overflow =
            "";
    }
);

/* =====================================================
   POPUP ALERTS (styled replacement for toasts, alert() and confirm())
===================================================== */
(function () {
    var ICONS = {
        success: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
        error: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M12 6v8"/><circle cx="12" cy="18.2" r="1.2" fill="currentColor" stroke="none"/></svg>',
        warning: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M12 6v8"/><circle cx="12" cy="18.2" r="1.2" fill="currentColor" stroke="none"/></svg>',
        info: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M12 11v6"/><circle cx="12" cy="7" r="1.2" fill="currentColor" stroke="none"/></svg>',
        confirm: '<svg viewBox="0 0 24 24" width="30" height="30" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M9.5 9a2.5 2.5 0 1 1 3.6 2.2c-.8.5-1.1 1-1.1 1.8"/><circle cx="12" cy="17.6" r="1.2" fill="currentColor" stroke="none"/></svg>'
    };
    var TITLES = { success: "Success", error: "Something went wrong", warning: "Please note", info: "Information", confirm: "Are you sure?" };
    var queue = [], showing = false;

    function normType(t) { return ICONS[t] ? t : (t === "danger" ? "error" : "info"); }

    function next() {
        if (showing || !queue.length) return;
        showing = true;
        render(queue.shift());
    }

    function render(o) {
        var type = normType(o.type);
        var overlay = document.createElement("div");
        overlay.className = "mkp-overlay";
        overlay.setAttribute("role", "alertdialog");
        overlay.setAttribute("aria-modal", "true");
        var box = document.createElement("div");
        box.className = "mkp-box mkp-" + type;
        var icon = document.createElement("div");
        icon.className = "mkp-icon";
        icon.innerHTML = ICONS[type];
        var h = document.createElement("h3");
        h.textContent = o.title || TITLES[type];
        var p = document.createElement("p");
        p.textContent = o.message || "";
        var actions = document.createElement("div");
        actions.className = "mkp-actions";
        box.appendChild(icon); box.appendChild(h); box.appendChild(p); box.appendChild(actions);
        overlay.appendChild(box);

        function close(result) {
            document.removeEventListener("keydown", onKey, true);
            overlay.classList.add("mkp-out");
            setTimeout(function () {
                overlay.remove();
                if (!document.querySelector(".mkp-overlay")) document.body.style.overflow = "";
                showing = false;
                if (result && o.onConfirm) o.onConfirm();
                if (!result && o.onCancel) o.onCancel();
                next();
            }, 180);
        }
        function onKey(e) {
            if (e.key === "Escape") { e.preventDefault(); close(false); }
        }

        if (o.confirm) {
            var cancel = document.createElement("button");
            cancel.type = "button"; cancel.className = "mkp-btn mkp-btn-ghost";
            cancel.textContent = o.cancelText || "Cancel";
            cancel.onclick = function () { close(false); };
            actions.appendChild(cancel);
        }
        var ok = document.createElement("button");
        ok.type = "button"; ok.className = "mkp-btn mkp-btn-main" + (o.danger ? " mkp-btn-danger" : "");
        ok.textContent = o.confirmText || (o.confirm ? "Yes, continue" : "OK");
        ok.onclick = function () { close(true); };
        actions.appendChild(ok);

        overlay.addEventListener("click", function (e) { if (e.target === overlay && !o.confirm) close(false); });
        document.addEventListener("keydown", onKey, true);
        document.body.appendChild(overlay);
        document.body.style.overflow = "hidden";
        requestAnimationFrame(function () { overlay.classList.add("mkp-in"); ok.focus(); });
    }

    var MK = window.MK = {
        popup: function (o) { queue.push(o || {}); next(); },
        alert: function (message, type) { MK.popup({ type: type || "info", message: String(message == null ? "" : message) }); },
        confirm: function (message, onConfirm, opts) {
            opts = opts || {};
            MK.popup({ type: "confirm", confirm: true, message: message, onConfirm: onConfirm,
                       title: opts.title, confirmText: opts.confirmText, cancelText: opts.cancelText, danger: opts.danger });
        }
    };

    // Browser alert() boxes become styled popups too.
    window.alert = function (m) { MK.alert(m, "warning"); };

    // Forms/buttons with data-confirm ask first, in a popup.
    document.addEventListener("submit", function (e) {
        var f = e.target;
        if (!f || !f.getAttribute || !f.hasAttribute("data-confirm") || f.__mkOk) return;
        e.preventDefault();
        var danger = f.getAttribute("data-confirm-danger") !== "false";
        MK.confirm(f.getAttribute("data-confirm"), function () { f.__mkOk = true; f.submit(); },
                   { confirmText: f.getAttribute("data-confirm-ok") || undefined, danger: danger });
    }, true);

    // Server flash messages (Flask flash()) -> popups.
    document.addEventListener("DOMContentLoaded", function () {
        var el = document.getElementById("mkFlashData");
        if (!el) return;
        try {
            JSON.parse(el.textContent).forEach(function (m) { MK.alert(m[1], m[0]); });
        } catch (err) {}
    });
})();
