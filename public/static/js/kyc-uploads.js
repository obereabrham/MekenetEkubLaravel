(function () {
  'use strict';

  const form = document.getElementById('kycForm');
  if (!form) return;

  const MAX_IMAGE_BYTES = 1024 * 1024;
  const idType = document.getElementById('idType');
  const frontInput = document.getElementById('frontInput');
  const frontLabel = document.getElementById('frontLabel');
  const backSlot = document.getElementById('backSlot');
  const backInput = document.getElementById('backInput');

  function clearPreview(preview) {
    const image = preview.querySelector('img');
    if (image && image.dataset.objectUrl) URL.revokeObjectURL(image.dataset.objectUrl);
    preview.replaceChildren();
  }

  function errorFor(slot) {
    let message = slot.querySelector('.kyc-file-error');
    if (!message) {
      message = document.createElement('p');
      message.className = 'kyc-file-error';
      message.setAttribute('role', 'alert');
      message.style.cssText = 'color:#b42318;font-size:.85rem;margin:8px 0 0';
      slot.appendChild(message);
    }
    return message;
  }

  function setSlotError(slot, message) {
    errorFor(slot).textContent = message || '';
    slot.style.borderColor = message ? '#b42318' : '';
  }

  function applyIdType() {
    const passport = idType && idType.value.toLowerCase() === 'passport';
    if (frontLabel) frontLabel.textContent = passport ? 'Passport photo' : 'National ID – Front';
    if (frontInput) frontInput.accept = 'image/*';
    if (backSlot) backSlot.hidden = !!passport;
    if (backInput) {
      backInput.disabled = !!passport;
      backInput.accept = 'image/*';
      if (passport) {
        backInput.value = '';
        const slot = backInput.closest('[data-slot]');
        const preview = slot && slot.querySelector('.kyc-preview');
        if (preview) clearPreview(preview);
        if (slot) setSlotError(slot, '');
      }
    }
  }

  form.querySelectorAll('[data-slot]').forEach(function (slot) {
    const input = slot.querySelector('input[type="file"]');
    const preview = slot.querySelector('.kyc-preview');
    if (!input || !preview) return;

    input.accept = 'image/*';

    slot.querySelectorAll('button[data-mode]').forEach(function (button) {
      button.addEventListener('click', function () {
        if (input.disabled) return;
        if (button.dataset.mode === 'camera') {
          input.setAttribute('capture', input.dataset.capture || 'environment');
        } else {
          input.removeAttribute('capture');
        }
        // Keep this synchronous with the user's tap so mobile browsers can open
        // their native gallery or camera chooser.
        input.click();
      });
    });

    input.addEventListener('change', function () {
      const file = input.files && input.files[0];
      if (!file) return;

      clearPreview(preview);
      if (!file.type || !file.type.startsWith('image/')) {
        input.value = '';
        setSlotError(slot, 'Choose an image file (JPG, PNG, or another supported image).');
        return;
      }
      if (file.size > MAX_IMAGE_BYTES) {
        input.value = '';
        setSlotError(slot, 'Image must be 1 MB or smaller.');
        return;
      }

      setSlotError(slot, '');
      const image = document.createElement('img');
      image.alt = 'Selected ' + (slot.querySelector('label')?.textContent.trim() || 'KYC photo');
      image.dataset.objectUrl = URL.createObjectURL(file);
      image.src = image.dataset.objectUrl;
      const name = document.createElement('span');
      name.textContent = file.name + ' · ' + Math.max(1, Math.ceil(file.size / 1024)) + ' KB';
      preview.append(image, name);
    });
  });

  if (idType) {
    idType.addEventListener('change', applyIdType);
    applyIdType();
  }

  form.addEventListener('submit', function (event) {
    // The form uses novalidate for the custom photo controls; retain standard
    // required-field and rules-acceptance checks for the rest of the form.
    if (!form.checkValidity()) {
      event.preventDefault();
      form.reportValidity();
      return;
    }

    for (const slot of form.querySelectorAll('[data-slot]')) {
      if (slot.hidden) continue;
      const input = slot.querySelector('input[type="file"]');
      if (!input || input.disabled) continue;
      const file = input.files && input.files[0];
      if (!file) {
        event.preventDefault();
        setSlotError(slot, 'Please upload or take this photo before submitting.');
        slot.scrollIntoView({ behavior: 'smooth', block: 'center' });
        return;
      }
      if (!file.type || !file.type.startsWith('image/') || file.size > MAX_IMAGE_BYTES) {
        event.preventDefault();
        setSlotError(slot, file.size > MAX_IMAGE_BYTES ? 'Image must be 1 MB or smaller.' : 'Choose an image file.');
        slot.scrollIntoView({ behavior: 'smooth', block: 'center' });
        return;
      }
    }
  });
})();
