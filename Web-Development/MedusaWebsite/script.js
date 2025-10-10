(function () {
    const body = document.body;
    body.classList.remove('no-js');

    const prefersReducedMotion = (typeof window.matchMedia === 'function')
        ? window.matchMedia('(prefers-reduced-motion: reduce)')
        : {
            matches: false,
            addEventListener: () => {},
            removeEventListener: () => {}
        };
    const header = document.querySelector('.site-header');
    const navToggle = document.querySelector('.nav-toggle');
    const nav = document.querySelector('.site-nav');
    const navLinks = nav ? nav.querySelectorAll('a[href^="#"]') : [];

    const updateHeaderState = () => {
        if (!header) return;
        header.dataset.scrolled = window.scrollY > 40 ? 'true' : 'false';
    };

    const closeNav = () => {
        if (!nav || !navToggle) return;
        navToggle.setAttribute('aria-expanded', 'false');
        navToggle.classList.remove('is-active');
        nav.dataset.open = 'false';
        body.classList.remove('menu-open');
    };

    const toggleNav = () => {
        if (!nav || !navToggle) return;
        const isExpanded = navToggle.getAttribute('aria-expanded') === 'true';
        const nextState = !isExpanded;

        navToggle.setAttribute('aria-expanded', String(nextState));
        nav.dataset.open = nextState ? 'true' : 'false';
        navToggle.classList.toggle('is-active', nextState);
        body.classList.toggle('menu-open', nextState);
    };

    if (navToggle && nav) {
        nav.dataset.open = 'false';
        navToggle.addEventListener('click', toggleNav);
        window.addEventListener('resize', () => {
            if (window.innerWidth > 960) {
                closeNav();
            }
        });
    }

    const allAnchorLinks = document.querySelectorAll('a[href^="#"]:not([href="#"])');
    const smoothScrollTo = (target) => {
        const headerHeight = header ? header.getBoundingClientRect().height : 0;
        const offset = Math.max(headerHeight, 72) + 16;
        const destination = target.getBoundingClientRect().top + window.scrollY - offset;
        window.scrollTo({
            top: destination,
            behavior: prefersReducedMotion.matches ? 'auto' : 'smooth'
        });
    };

    allAnchorLinks.forEach((link) => {
        const href = link.getAttribute('href');
        if (!href || href === '#') return;

        const target = document.querySelector(href);
        if (!target) return;

        link.addEventListener('click', (event) => {
            if (window.location.pathname !== link.pathname) return;
            event.preventDefault();
            smoothScrollTo(target);
            closeNav();
        });
    });

    if ('IntersectionObserver' in window && navLinks.length) {
        const navMap = new Map();
        navLinks.forEach((link) => {
            const id = link.getAttribute('href')?.split('#')[1];
            if (!id) return;
            const section = document.getElementById(id);
            if (section) navMap.set(section, link);
        });

        const observer = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                const link = navMap.get(entry.target);
                if (!link) return;
                if (entry.isIntersecting) {
                    navLinks.forEach((navLink) => navLink.classList.remove('is-active'));
                    link.classList.add('is-active');
                }
            });
        }, {
            threshold: 0.4,
            rootMargin: '-20% 0px -40% 0px'
        });

        navMap.forEach((_, section) => observer.observe(section));
    }

    const heroMedia = document.querySelector('#home .section__media');
    if (heroMedia) {
        const images = heroMedia.dataset.heroImages
            ? heroMedia.dataset.heroImages.split(',').map((src) => src.trim()).filter(Boolean)
            : [];
        let index = 0;

        const swapImage = (nextIndex) => {
            if (!images.length) return;
            heroMedia.classList.add('is-fading');
            setTimeout(() => {
                heroMedia.style.backgroundImage = `url('${images[nextIndex]}')`;
                heroMedia.classList.remove('is-fading');
            }, 400);
        };

        if (images.length) {
            heroMedia.style.backgroundImage = `url('${images[0]}')`;
            if (images.length > 1 && !prefersReducedMotion.matches) {
                setInterval(() => {
                    index = (index + 1) % images.length;
                    swapImage(index);
                }, 8000);
            }
        }
    }

    const statusBadge = document.querySelector('[data-status-badge]');
    const setStatus = (state) => {
        if (!statusBadge) return;
        statusBadge.dataset.state = state;
        statusBadge.textContent = state === 'online' ? 'Online' : 'Offline';
    };
    setStatus('online');

    const copyButtons = document.querySelectorAll('[data-copy]');
    if (copyButtons.length && navigator.clipboard) {
        copyButtons.forEach((button) => {
            button.addEventListener('click', async () => {
                const label = button.querySelector('span');
                const originalText = label ? label.textContent : 'Copiar';
                try {
                    await navigator.clipboard.writeText(button.dataset.copy || '');
                    if (label) label.textContent = 'Copiado!';
                    button.classList.add('is-success');
                    setTimeout(() => {
                        if (label) label.textContent = originalText;
                        button.classList.remove('is-success');
                    }, 2200);
                } catch (error) {
                    console.error('Falha ao copiar para a área de transferência:', error);
                    if (label) {
                        label.textContent = 'Tenta outra vez';
                        setTimeout(() => {
                            label.textContent = originalText;
                        }, 2200);
                    }
                }
            });
        });
    }

    const connectButtons = document.querySelectorAll('[data-connect]');
    if (connectButtons.length) {
        connectButtons.forEach((button) => {
            button.addEventListener('click', (event) => {
                const target = button.dataset.connect;
                if (!target) return;
                event.preventDefault();
                window.location.href = target;
                button.classList.add('is-success');
                setTimeout(() => {
                    button.classList.remove('is-success');
                }, 2000);
            });
        });
    }

    const initCarousel = (carousel) => {
        const track = carousel.querySelector('.carousel__track');
        const viewport = carousel.querySelector('.carousel__viewport');
        if (!track || !viewport) return;

        const slides = Array.from(track.children);
        if (!slides.length) return;

        const dotsContainer = carousel.querySelector('.carousel__dots');
        const prevButton = carousel.querySelector('.carousel__arrow--prev');
        const nextButton = carousel.querySelector('.carousel__arrow--next');
        const name = carousel.getAttribute('data-carousel') || 'default';
        const autoplayDelay = prefersReducedMotion.matches ? 0 : (name === 'core' ? 6000 : 5000);

        let index = 0;
        let timer = null;
        let dots = [];
        let gapSize = 0;
        let baseWidth = 0;
        let totalWidth = 0;
        let maxIndex = Math.max(0, slides.length - 1);
        let maxTranslate = 0;
        let currentTranslate = 0;

        const measure = () => {
            if (!slides.length) return;
            const trackStyles = window.getComputedStyle(track);
            const rawGap = parseFloat(trackStyles.columnGap || trackStyles.gap || '0');
            gapSize = Number.isNaN(rawGap) ? 0 : rawGap;
            const styleWidth = parseFloat(window.getComputedStyle(slides[0]).width || '0');
            baseWidth = !Number.isNaN(styleWidth) && styleWidth > 0
                ? styleWidth
                : slides[0].getBoundingClientRect().width;
            const slideWidth = baseWidth + gapSize;
            totalWidth = slides.length * baseWidth + Math.max(0, (slides.length - 1) * gapSize);
            const viewportWidth = viewport.getBoundingClientRect().width;
            maxIndex = Math.max(0, slides.length - 1);
            maxTranslate = Math.max(0, totalWidth - viewportWidth);
            return slideWidth;
        };

        const applyTransform = (immediate = false) => {
            const slideWidth = measure();
            if (!slideWidth) return;
            const viewportWidth = viewport.getBoundingClientRect().width;
            const slideCenter = index * slideWidth + baseWidth / 2;
            let translate = slideCenter - viewportWidth / 2;
            translate = Math.max(0, Math.min(translate, maxTranslate));
            currentTranslate = translate;

            if (immediate) {
                const previousTransition = track.style.transition;
                track.style.transition = 'none';
                track.style.transform = `translateX(-${translate}px)`;
                // Force reflow to apply transform without transition
                track.getBoundingClientRect();
                track.style.transition = previousTransition || '';
            } else {
                track.style.transform = `translateX(-${translate}px)`;
            }
        };

        const updateActiveStates = () => {
            let activeIndex = index;
            if (slides.length > 1) {
                if (index === 0) {
                    activeIndex = 0;
                } else if (index === maxIndex) {
                    activeIndex = slides.length - 1;
                } else {
                    activeIndex = index;
                }
            }
            slides.forEach((slide, slideIndex) => {
                const slideStart = slideIndex * (baseWidth + gapSize);
                const slideEnd = slideStart + baseWidth;
                const viewportStart = currentTranslate;
                const viewportEnd = currentTranslate + viewport.getBoundingClientRect().width;
                const isVisible = slideEnd > viewportStart && slideStart < viewportEnd;
                slide.classList.toggle('is-visible', isVisible);
                slide.classList.toggle('is-active', slideIndex === activeIndex);
            });
            dots.forEach((dot, dotIndex) => {
                const isActive = dotIndex === index;
                dot.classList.toggle('is-active', isActive);
                dot.setAttribute('aria-pressed', isActive ? 'true' : 'false');
            });
        };

        const buildDots = (count) => {
            if (!dotsContainer) return;
            dotsContainer.innerHTML = '';
            dots = [];
            for (let i = 0; i < count; i += 1) {
                const dot = document.createElement('button');
                dot.type = 'button';
                dot.className = 'carousel__dot';
                dot.setAttribute('aria-label', `Ir para slide ${i + 1}`);
                dot.setAttribute('aria-pressed', i === 0 ? 'true' : 'false');
                dot.addEventListener('click', () => {
                    stopAutoplay();
                    goTo(i, { immediate: true });
                    startAutoplay();
                });
                dotsContainer.appendChild(dot);
                dots.push(dot);
            }
        };

        const goTo = (nextIndex, { immediate = false } = {}) => {
            if (!slides.length) return;
            const slideWidth = measure();
            if (!slideWidth) {
                requestAnimationFrame(() => goTo(nextIndex, { immediate }));
                return;
            }

            const expectedDots = slides.length;
            if (dotsContainer && dots.length !== expectedDots) {
                buildDots(expectedDots);
            }

            if (nextIndex > maxIndex) {
                index = 0;
            } else if (nextIndex < 0) {
                index = maxIndex;
            } else {
                index = nextIndex;
            }

            applyTransform(immediate);
            updateActiveStates();
        };

        const prev = () => goTo(index - 1);
        const next = () => goTo(index + 1);

        if (prevButton) {
            prevButton.addEventListener('click', () => {
                stopAutoplay();
                prev();
                startAutoplay();
            });
        }

        if (nextButton) {
            nextButton.addEventListener('click', () => {
                stopAutoplay();
                next();
                startAutoplay();
            });
        }

        const stopAutoplay = () => {
            if (timer) {
                clearInterval(timer);
                timer = null;
            }
        };

        const startAutoplay = () => {
            if (!autoplayDelay) return;
            const slideWidth = measure();
            if (!slideWidth || maxIndex <= 0) return;
            stopAutoplay();
            timer = setInterval(next, autoplayDelay);
        };

        carousel.addEventListener('mouseenter', stopAutoplay);
        carousel.addEventListener('mouseleave', startAutoplay);
        carousel.addEventListener('focusin', stopAutoplay);
        carousel.addEventListener('focusout', startAutoplay);

        window.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                stopAutoplay();
            } else {
                startAutoplay();
            }
        });

        window.addEventListener('resize', () => {
            goTo(index, { immediate: true });
            startAutoplay();
        });

        measure();
        if (dotsContainer) {
            buildDots(slides.length);
        }
        goTo(0, { immediate: true });
        startAutoplay();
    };

    document.querySelectorAll('.carousel[data-carousel]').forEach(initCarousel);

    let scrollTimeout;
    window.addEventListener('scroll', () => {
        updateHeaderState();
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(updateHeaderState, 150);
    }, { passive: true });

    updateHeaderState();
})();

