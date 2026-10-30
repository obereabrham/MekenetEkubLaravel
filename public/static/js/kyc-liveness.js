(function () {
  const form = document.getElementById('kycForm');
  if (!form) return;

  const idType = document.getElementById('idType');
  const backSlot = document.getElementById('backSlot');
  const backInput = document.getElementById('backInput');
  const frontInput = document.getElementById('frontInput');
  const frontLabel = document.getElementById('frontLabel');
  const liveDialog = document.getElementById('liveCheckDialog');
  const livePreview = document.getElementById('livePreview');
  const liveStart = document.getElementById('startLiveCheck');
  const liveNext = document.getElementById('nextLiveStep');
  const liveCancel = document.getElementById('cancelLiveCheck');
  const liveError = document.getElementById('liveError');
  const liveStepCount = document.getElementById('liveStepCount');
  const liveStepText = document.getElementById('liveStepText');
  const liveIndicator = document.getElementById('liveRecIndicator');
  const liveValue = document.getElementById('livenessVerified');
  const liveStatus = document.getElementById('liveCheckStatus');
  const liveSlot = document.getElementById('liveSlot');
  const steps = [
    'Center your face in the guide and hold still.',
    'Blink both eyes naturally two times.',
    'Turn your head left, then right, then face forward.'
  ];
  const wasmPath = 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.2.0/wasm';
  const modelPath = 'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task';
  let stream = null, landmarker = null, animation = 0, stage = 0;
  let stagePassed = false, centerSince = 0, blinkCount = 0, openFrames = 0;
  let closedEyes = false, turnedLeft = false, turnedRight = false;
  let lastVideoTime = -1;

  function setStatus(message) {
    if (message !== liveStepText.textContent) liveStepText.textContent = message;
  }
  function stopLive() {
    if (animation) cancelAnimationFrame(animation);
    animation = 0;
    if (stream) stream.getTracks().forEach(function (track) { track.stop(); });
    stream = null;
    livePreview.srcObject = null;
    if (landmarker) landmarker.close();
    landmarker = null;
  }
  function clearStep() {
    stagePassed = false;
    centerSince = 0;
    blinkCount = 0;
    openFrames = 0;
    closedEyes = false;
    turnedLeft = false;
    turnedRight = false;
    lastVideoTime = -1;
    liveStepCount.textContent = 'STEP ' + (stage + 1) + ' OF ' + steps.length;
    liveStepText.textContent = steps[stage];
    liveNext.textContent = stage === steps.length - 1 ? 'Finish live check' : 'Continue';
    liveNext.disabled = true;
  }
  function passStep(message) {
    if (stagePassed) return;
    stagePassed = true;
    liveNext.disabled = false;
    liveStepText.textContent = message + ' Tap Continue to move on.';
    liveIndicator.textContent = 'STEP PASSED';
  }
  function resetRun() {
    stage = 0;
    stagePassed = false;
    liveValue.value = '';
    liveSlot.classList.remove('missing');
    liveStatus.textContent = '';
    liveError.textContent = '';
    liveIndicator.textContent = 'CAMERA READY';
    liveStart.hidden = false;
    liveStart.disabled = false;
    liveNext.hidden = true;
    clearStep();
    liveStepCount.textContent = 'READY';
    liveStepText.textContent = 'Allow camera access to start. The live check is processed here and no check video is made.';
  }

  function processFace(result) {
    const landmarks = result.faceLandmarks && result.faceLandmarks[0];
    if (!landmarks || result.faceLandmarks.length !== 1) {
      centerSince = 0;
      setStatus(landmarks ? 'Only one face may be in the camera view.' : 'No face detected. Move your face into the guide.');
      return;
    }
    let minX = 1, maxX = 0, minY = 1, maxY = 0;
    landmarks.forEach(function (point) {
      minX = Math.min(minX, point.x); maxX = Math.max(maxX, point.x);
      minY = Math.min(minY, point.y); maxY = Math.max(maxY, point.y);
    });
    const x = 1 - (minX + maxX) / 2;
    const y = (minY + maxY) / 2;

    if (stage === 0) {
      const centered = x > 0.34 && x < 0.66 && y > 0.22 && y < 0.78;
      if (!centered) { centerSince = 0; setStatus('Move your face to the middle of the guide.'); return; }
      centerSince = centerSince || performance.now();
      const held = performance.now() - centerSince;
      if (held >= 1800) passStep('Face centered and held still.');
      else setStatus('Good. Hold still for ' + Math.max(1, Math.ceil((1800 - held) / 1000)) + ' more seconds.');
      return;
    }

    if (stage === 1) {
      const blendshapes = result.faceBlendshapes && result.faceBlendshapes[0]
        ? result.faceBlendshapes[0].categories : [];
      const left = blendshapes.find(function (shape) { return shape.categoryName === 'eyeBlinkLeft'; });
      const right = blendshapes.find(function (shape) { return shape.categoryName === 'eyeBlinkRight'; });
      if (!left || !right) { setStatus('Keep both eyes visible and look at the camera.'); return; }
      const open = left.score < 0.30 && right.score < 0.30;
      const closed = left.score > 0.62 && right.score > 0.62;
      if (open) {
        openFrames++;
        if (closedEyes && openFrames >= 2) {
          closedEyes = false; blinkCount++;
          if (blinkCount >= 2) passStep('Two blinks detected.');
          else setStatus('Blink once more. Detected ' + blinkCount + ' of 2.');
        }
      } else if (closed && openFrames >= 2) {
        closedEyes = true; openFrames = 0;
        setStatus('Eyes closed. Open them to complete the blink.');
      }
      return;
    }

    if (stage === 2) {
      const nose = landmarks[1], eyeA = landmarks[33], eyeB = landmarks[263];
      const eyeDistance = Math.hypot(eyeA.x - eyeB.x, eyeA.y - eyeB.y);
      if (!nose || !eyeA || !eyeB || eyeDistance < 0.01) {
        setStatus('Keep your full face visible and turn your head.'); return;
      }
      const yaw = (nose.x - (eyeA.x + eyeB.x) / 2) / eyeDistance;
      if (yaw < -0.17) { turnedLeft = true; setStatus('Left turn detected. Turn your head to the other side.'); }
      else if (yaw > 0.17) { turnedRight = true; setStatus('Right turn detected. Face forward to finish.'); }
      else if (turnedLeft && turnedRight && Math.abs(yaw) < 0.07) passStep('Left and right head turns detected.');
      else if (!turnedLeft) setStatus('Slowly turn your head to the left.');
      else if (!turnedRight) setStatus('Now slowly turn your head to the right.');
      return;
    }

  }

  function checkFrame() {
    if (!liveDialog.open || !landmarker || !livePreview.srcObject) return;
    if (livePreview.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        livePreview.currentTime !== lastVideoTime) {
      lastVideoTime = livePreview.currentTime;
      const result = landmarker.detectForVideo(livePreview, performance.now());
      processFace(result);
    }
    animation = requestAnimationFrame(checkFrame);
  }

  document.getElementById('openLiveCheck').addEventListener('click', function () {
    resetRun();
    liveDialog.showModal();
  });
  liveStart.addEventListener('click', async function () {
    liveError.textContent = '';
    liveStart.disabled = true;
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      liveError.textContent = 'Allow camera access from a secure HTTPS page in a current browser.';
      liveStart.disabled = false;
      return;
    }
    try {
      liveStepText.textContent = 'Starting the on-device face detector…';
      const vision = await import('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.2.0/vision_bundle.mjs');
      const files = await vision.FilesetResolver.forVisionTasks(wasmPath);
      landmarker = await vision.FaceLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetPath: modelPath, delegate: 'CPU' },
        runningMode: 'VIDEO',
        numFaces: 1,
        outputFaceBlendshapes: true
      });
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 840 } },
        audio: false
      });
      if (!liveDialog.open) { stopLive(); return; }
      livePreview.srcObject = stream;
      await livePreview.play();
      liveStart.hidden = true;
      liveNext.hidden = false;
      liveIndicator.textContent = 'LIVE FACE CHECK';
      clearStep();
      animation = requestAnimationFrame(checkFrame);
    } catch (error) {
      stopLive();
      liveError.textContent = 'Could not start the in-page face check. Allow camera access and use the site over HTTPS, then try again.';
      liveStart.disabled = false;
      liveStepText.textContent = 'Camera and on-device face detection are required to continue.';
    }
  });
  liveNext.addEventListener('click', function () {
    if (!stagePassed) return;
    if (stage === steps.length - 1) {
      liveValue.value = '1';
      liveSlot.classList.remove('missing');
      liveStatus.textContent = 'Live face check passed on this device.';
      liveDialog.close();
      stopLive();
      return;
    }
    stage++;
    clearStep();
    liveIndicator.textContent = 'LIVE · STEP ' + (stage + 1);
  });
  function cancelLive() {
    stopLive();
    liveDialog.close();
  }
  liveCancel.addEventListener('click', cancelLive);
  liveDialog.addEventListener('cancel', function (event) { event.preventDefault(); cancelLive(); });

  function clearSlot(slot) {
    const input = slot.querySelector('input[type="file"]');
    input.value = '';
    slot.querySelector('.kyc-preview').innerHTML = '';
  }
  function applyIdType() {
    const passport = idType.value === 'Passport';
    backSlot.style.display = passport ? 'none' : '';
    backInput.disabled = passport;
    if (passport) { clearSlot(backSlot); frontLabel.textContent = 'Passport (1 image)'; frontInput.accept = 'image/*'; }
    else { frontLabel.textContent = 'National ID – Front'; frontInput.accept = 'image/*,.pdf'; }
  }
  idType.addEventListener('change', applyIdType);
  applyIdType();

  document.querySelectorAll('[data-slot]').forEach(function (slot) {
    const input = slot.querySelector('input[type="file"]');
    const preview = slot.querySelector('.kyc-preview');
    slot.querySelectorAll('button[data-mode]').forEach(function (button) {
      button.addEventListener('click', function () {
        if (button.dataset.mode === 'camera') input.setAttribute('capture', input.dataset.capture);
        else input.removeAttribute('capture');
        input.click();
      });
    });
    input.addEventListener('change', function () {
      preview.innerHTML = '';
      slot.classList.remove('missing');
      const file = input.files && input.files[0];
      if (!file) return;
      const url = URL.createObjectURL(file);
      let media;
      if (file.type.indexOf('image/') === 0) { media = document.createElement('img'); media.src = url; }
      else if (file.type.indexOf('video/') === 0) { media = document.createElement('video'); media.src = url; media.controls = true; media.muted = true; }
      if (media) preview.appendChild(media);
      const label = document.createElement('span');
      label.textContent = file.name;
      preview.appendChild(label);
    });
  });

  const agreementDialog = document.getElementById('agreementRecordDialog');
  const agreementInput = document.getElementById('agreementVideoInput');
  const agreementPreview = document.getElementById('agreementRecordPreview');
  const agreementStatus = document.getElementById('agreementRecordStatus');
  const startAgreementButton = document.getElementById('startAgreementRecording');
  const stopAgreementButton = document.getElementById('stopAgreementRecording');
  const useAgreementButton = document.getElementById('useAgreementRecording');
  let agreementStream = null, agreementRecorder = null, agreementTimer = 0;
  let agreementChunks = [], agreementBlob = null, agreementObjectUrl = null;
  let agreementCancelled = false;

  function stopAgreementTracks() {
    if (agreementStream) agreementStream.getTracks().forEach(function (track) { track.stop(); });
    agreementStream = null;
    agreementPreview.srcObject = null;
  }
  function resetAgreementRecorder() {
    if (agreementTimer) clearTimeout(agreementTimer);
    agreementTimer = 0;
    agreementCancelled = true;
    if (agreementRecorder && agreementRecorder.state === 'recording') {
      try { agreementRecorder.stop(); } catch (_) {}
    }
    stopAgreementTracks();
    agreementRecorder = null;
  }
  document.getElementById('openAgreementRecorder').addEventListener('click', function () {
    agreementCancelled = false;
    agreementChunks = [];
    agreementBlob = null;
    agreementStatus.textContent = '';
    agreementPreview.removeAttribute('src');
    agreementPreview.controls = false;
    startAgreementButton.hidden = false;
    startAgreementButton.disabled = false;
    stopAgreementButton.hidden = true;
    useAgreementButton.hidden = true;
    agreementDialog.showModal();
  });
  startAgreementButton.addEventListener('click', async function () {
    agreementStatus.textContent = '';
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.MediaRecorder) {
      agreementStatus.textContent = 'This browser does not support in-page video recording. Use a current browser over HTTPS.';
      return;
    }
    startAgreementButton.disabled = true;
    try {
      agreementCancelled = false;
      agreementStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 840 } },
        audio: true
      });
      agreementPreview.srcObject = agreementStream;
      agreementPreview.controls = false;
      await agreementPreview.play();
      const mimeTypes = ['video/webm;codecs=vp8,opus', 'video/webm', 'video/mp4'];
      const mimeType = mimeTypes.find(function (type) {
        return MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(type);
      });
      agreementRecorder = mimeType
        ? new MediaRecorder(agreementStream, { mimeType: mimeType })
        : new MediaRecorder(agreementStream);
      agreementChunks = [];
      agreementRecorder.addEventListener('dataavailable', function (event) {
        if (event.data && event.data.size) agreementChunks.push(event.data);
      });
      agreementRecorder.addEventListener('stop', function () {
        if (agreementCancelled) return;
        if (agreementTimer) clearTimeout(agreementTimer);
        agreementTimer = 0;
        agreementBlob = new Blob(agreementChunks, { type: agreementRecorder.mimeType || mimeType || 'video/webm' });
        stopAgreementTracks();
        if (!agreementBlob.size) {
          agreementStatus.textContent = 'No video was captured. Please record again.';
          startAgreementButton.hidden = false;
          startAgreementButton.disabled = false;
          stopAgreementButton.hidden = true;
          return;
        }
        if (agreementObjectUrl) URL.revokeObjectURL(agreementObjectUrl);
        agreementObjectUrl = URL.createObjectURL(agreementBlob);
        agreementPreview.srcObject = null;
        agreementPreview.src = agreementObjectUrl;
        agreementPreview.controls = true;
        agreementPreview.muted = false;
        agreementPreview.load();
        startAgreementButton.hidden = true;
        stopAgreementButton.hidden = true;
        useAgreementButton.hidden = false;
        agreementStatus.textContent = 'Recording complete. Play it back, then use it or record again.';
      });
      agreementRecorder.start(250);
      startAgreementButton.hidden = true;
      stopAgreementButton.hidden = false;
      agreementStatus.textContent = 'Recording in this page… Say the agreement clearly.';
      agreementTimer = window.setTimeout(function () {
        if (agreementRecorder && agreementRecorder.state === 'recording') agreementRecorder.stop();
      }, 20000);
    } catch (error) {
      stopAgreementTracks();
      startAgreementButton.disabled = false;
      agreementStatus.textContent = 'Could not start the in-page camera or microphone. Allow access and try again.';
    }
  });
  stopAgreementButton.addEventListener('click', function () {
    if (agreementRecorder && agreementRecorder.state === 'recording') agreementRecorder.stop();
  });
  useAgreementButton.addEventListener('click', function () {
    if (!agreementBlob) return;
    try {
      const extension = agreementBlob.type.indexOf('mp4') >= 0 ? 'mp4' : 'webm';
      const file = new File([agreementBlob], 'agreement.' + extension, { type: agreementBlob.type || 'video/webm' });
      const transfer = new DataTransfer();
      transfer.items.add(file);
      agreementInput.files = transfer.files;
      agreementInput.dispatchEvent(new Event('change', { bubbles: true }));
      agreementDialog.close();
      resetAgreementRecorder();
    } catch (error) {
      agreementStatus.textContent = 'Could not attach this recording. Try recording it again.';
    }
  });
  function cancelAgreementRecording() {
    resetAgreementRecorder();
    agreementDialog.close();
  }
  document.getElementById('cancelAgreementRecording').addEventListener('click', cancelAgreementRecording);
  agreementDialog.addEventListener('cancel', function (event) {
    event.preventDefault();
    cancelAgreementRecording();
  });
  agreementDialog.addEventListener('close', function () {
    if (agreementRecorder || agreementStream) resetAgreementRecorder();
  });
  window.addEventListener('beforeunload', function () {
    resetAgreementRecorder();
    if (agreementObjectUrl) URL.revokeObjectURL(agreementObjectUrl);
  });

  form.addEventListener('submit', function (event) {
    let firstMissing = null;
    document.querySelectorAll('[data-slot]').forEach(function (slot) {
      const input = slot.querySelector('input[type="file"]');
      if (slot.style.display === 'none' || input.disabled) return;
      if (!input.files || !input.files.length) {
        slot.classList.add('missing');
        if (!firstMissing) firstMissing = slot;
      }
    });
    if (liveValue.value !== '1') {
      liveSlot.classList.add('missing');
      if (!firstMissing) firstMissing = liveSlot;
    }
    if (firstMissing) {
      event.preventDefault();
      firstMissing.scrollIntoView({ behavior: 'smooth', block: 'center' });
      alert('Pass the live face check and add each required photo, ID, and separate agreement video before submitting.');
    }
  });
})();
