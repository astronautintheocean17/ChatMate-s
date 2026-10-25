/*
 * ChatMate install prompt.
 *
 * Deliberately small: show the popup shortly after load, install with the
 * browser's native prompt, or say the installer is not ready. Closing it
 * lasts for this tab session only.
 *
 * web/flutter_bootstrap.js does not register Flutter's generated service
 * worker (it unregisters itself). web/service-worker.js keeps the origin
 * installable.
 */
(function () {
  'use strict';

  var DISMISS_KEY = 'chatmate.installDismissed';
  var deferredPrompt = null;
  var installed = false;
  var modal = null;
  var card = null;
  var installButton = null;
  var status = null;

  function isStandalone() {
    return (
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
      window.navigator.standalone === true
    );
  }

  function show() {
    if (!modal || installed || modal.classList.contains('is-open')) return;
    modal.classList.add('is-open');
    modal.setAttribute('aria-hidden', 'false');
    if (card && card.focus) card.focus();
  }

  function hide() {
    if (!modal) return;
    modal.classList.remove('is-open');
    modal.setAttribute('aria-hidden', 'true');
    if (modal.contains(document.activeElement) && document.activeElement.blur) {
      document.activeElement.blur();
    }
  }

  function clearStatus() {
    if (!status) return;
    status.textContent = '';
    status.hidden = true;
  }

  function setStatus(message) {
    if (!status) return;
    status.textContent = message;
    status.hidden = false;
  }

  function dismiss() {
    if (!modal || !modal.classList.contains('is-open')) return;
    hide();
    try {
      window.sessionStorage.setItem(DISMISS_KEY, 'true');
    } catch (error) {
      /* Storage can be blocked; closing still works for this page. */
    }
  }

  async function install() {
    if (!deferredPrompt) {
      setStatus("Use your browser's Install or Add to Home Screen option.");
      return;
    }

    var prompt = deferredPrompt;
    deferredPrompt = null;

    try {
      var choice = await prompt.prompt();
      if (choice && choice.outcome === 'accepted') {
        installed = true;
        hide();
        try {
          window.sessionStorage.removeItem(DISMISS_KEY);
        } catch (error) {
          /* Nothing to clean up. */
        }
      }
    } catch (error) {
      if (window.console && window.console.warn) {
        window.console.warn('[ChatMate] Install prompt failed.', error);
      }
    }
  }

  function bind() {
    modal = document.getElementById('cm-install');
    installButton = document.getElementById('cm-install-action');
    status = document.getElementById('cm-install-status');
    var closeButton = document.getElementById('cm-install-close');
    card = modal && modal.querySelector('.cm-card');
    if (!modal || !card || !installButton || !closeButton) return false;

    installButton.addEventListener('click', install);
    closeButton.addEventListener('click', dismiss);
    modal.addEventListener('click', function (event) {
      if (event.target === modal) dismiss();
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') dismiss();
    });
    return true;
  }

  function hideBoot() {
    var boot = document.getElementById('chatmate-boot');
    if (!boot) return;
    boot.classList.add('is-hidden');
    window.setTimeout(function () {
      if (boot.parentNode) boot.parentNode.removeChild(boot);
    }, 500);
  }

  function init() {
    installed = isStandalone();
    if (!bind() || installed) return;

    var dismissed = false;
    try {
      dismissed = window.sessionStorage.getItem(DISMISS_KEY) === 'true';
    } catch (error) {
      /* Treat blocked storage as not dismissed. */
    }

    if (!dismissed) window.setTimeout(show, 1500);
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    if (installed) return;
    deferredPrompt = event;
    clearStatus();
    show();
  });

  window.addEventListener('appinstalled', function () {
    installed = true;
    deferredPrompt = null;
    hide();
    try {
      window.sessionStorage.removeItem(DISMISS_KEY);
    } catch (error) {
      /* Nothing to clean up. */
    }
  });

  window.addEventListener('flutter-first-frame', hideBoot);
  window.setTimeout(hideBoot, 9000);

  if ('serviceWorker' in navigator && window.isSecureContext) {
    navigator.serviceWorker.register('service-worker.js').catch(function (error) {
      if (window.console && window.console.warn) {
        window.console.warn('[ChatMate] Service worker registration failed.', error);
      }
    });
  }

  if (window.matchMedia) {
    var standaloneQuery = window.matchMedia('(display-mode: standalone)');
    var onStandaloneChange = function (event) {
      if (event.matches) {
        installed = true;
        hide();
      }
    };
    if (standaloneQuery.addEventListener) {
      standaloneQuery.addEventListener('change', onStandaloneChange);
    } else if (standaloneQuery.addListener) {
      standaloneQuery.addListener(onStandaloneChange);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
