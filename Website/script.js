(() => {
    'use strict';

    // --- Theme Toggle ---
    const html = document.documentElement;
    const toggle = document.getElementById('themeToggle');
    const overlay = document.getElementById('themeOverlay');
    const THEME_KEY = 'pocket-server-theme';

    // Load saved theme or default to dark
    const savedTheme = localStorage.getItem(THEME_KEY) || 'dark';
    html.setAttribute('data-theme', savedTheme);

    toggle.addEventListener('click', () => {
        const current = html.getAttribute('data-theme');
        const next = current === 'dark' ? 'light' : 'dark';

        // Flash overlay mid-transition for a cinematic wipe
        overlay.classList.add('flash');
        setTimeout(() => {
            html.setAttribute('data-theme', next);
            localStorage.setItem(THEME_KEY, next);
        }, 180);
        setTimeout(() => {
            overlay.classList.remove('flash');
        }, 520);
    });

    // --- Smooth Scroll ---
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', e => {
            e.preventDefault();
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // --- Scroll Reveal ---
    const reveals = document.querySelectorAll('.reveal');

    const revealObserver = new IntersectionObserver(
        (entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('active');
                    observer.unobserve(entry.target);
                }
            });
        },
        { threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
    );

    reveals.forEach(el => revealObserver.observe(el));

    // --- Copy to Clipboard ---
    const toast = document.getElementById('toast');
    let toastTimer;

    document.querySelectorAll('.copy-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
            const code = btn.closest('.code-block').querySelector('code');
            const text = code.innerText;

            try {
                await navigator.clipboard.writeText(text);
                showToast('Copied to clipboard');

                // Visual feedback on button
                btn.classList.add('copied');
                const label = btn.querySelector('.copy-label');
                if (label) {
                    const original = label.textContent;
                    label.textContent = 'Copied!';
                    setTimeout(() => {
                        label.textContent = original;
                        btn.classList.remove('copied');
                    }, 2000);
                }
            } catch {
                showToast('Failed to copy');
            }
        });
    });

    function showToast(message) {
        toast.textContent = message;
        toast.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => toast.classList.remove('show'), 2500);
    }

    // --- Nav background on scroll ---
    const nav = document.getElementById('nav');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const y = window.scrollY;
        if (y > 100) {
            nav.style.borderBottomColor = 'var(--border-strong)';
        } else {
            nav.style.borderBottomColor = 'var(--border)';
        }
        lastScroll = y;
    }, { passive: true });
})();
