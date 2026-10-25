/*
 * ChatMate install prompt.
 *
 * A persistent install tab stays at the side of the app until ChatMate is
 * installed. Tapping it starts the browser installer immediately when Chrome/
 * Edge has offered it; otherwise it opens the branded install card.
 *
 * web/flutter_bootstrap.js does not register Flutter's generated service
 * worker (it unregisters itself). web/service-worker.js keeps the origin
 * installable and runtime-caches large static assets.
 */
(function () {
  'use strict';

  var deferredPrompt = null;
  var installed = false;
  var modal = null;
  var card = null;
  var fab = null;
  var installButton = null;
  var status = null;

  function isStandalone() {
    return (
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
      window.navigator.standalone === true
    );
  }

  function showFab() {
    if (fab && !installed) fab.hidden = false;
  }

  function hideFab() {
    if (fab) fab.hidden = true;
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
    hide();
  }

  async function install() {
    if (!deferredPrompt) {
      show();
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
        hideFab();
      }
    } catch (error) {
      show();
      setStatus("Couldn't open the installer. Use your browser menu.");
      if (window.console && window.console.warn) {
        window.console.warn('[ChatMate] Install prompt failed.', error);
      }
    }
  }

  function startInstall() {
    if (installed) return;
    if (deferredPrompt) {
      install();
    } else {
      show();
      setStatus("Use your browser's Install or Add to Home Screen option.");
    }
  }

  function bind() {
    modal = document.getElementById('cm-install');
    installButton = document.getElementById('cm-install-action');
    status = document.getElementById('cm-install-status');
    fab = document.getElementById('cm-install-fab');
    var closeButton = document.getElementById('cm-install-close');
    card = modal && modal.querySelector('.cm-card');
    if (!modal || !card || !installButton || !closeButton) return false;

    installButton.addEventListener('click', install);
    if (fab) fab.addEventListener('click', startInstall);
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
    if (!bind()) return;
    if (installed) {
      hideFab();
      return;
    }
    showFab();
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    if (installed) return;
    deferredPrompt = event;
    clearStatus();
  });

  window.addEventListener('appinstalled', function () {
    installed = true;
    deferredPrompt = null;
    hide();
    hideFab();
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
        hideFab();
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
