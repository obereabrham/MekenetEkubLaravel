(function () {
  'use strict';

  const form = document.getElementById('kycForm');
  if (!form) return;

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
  let stream = null;
  let landmarker = null;
  let animation = 0;
  let stage = 0;
  let stagePassed = false;
  let centerSince = 0;
  let blinkCount = 0;
  let openFrames = 0;
  let closedEyes = false;
  let turnedLeft = false;
  let turnedRight = false;
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
    if (landmarker) {
      try { landmarker.close(); } catch (_) {}
    }
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
    stopLive();
    stage = 0;
    stagePassed = false;
    liveValue.value = '0';
    liveSlot.classList.remove('missing');
    liveStatus.textContent = 'Not completed';
    liveError.textContent = '';
    liveIndicator.textContent = 'CAMERA READY';
    liveStart.hidden = false;
    liveStart.disabled = false;
    liveNext.hidden = true;
    liveNext.disabled = true;
    clearStep();
    liveStepCount.textContent = 'READY';
    liveStepText.textContent = 'Start the camera check. The live face check runs on this device; no video is recorded or uploaded.';
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
      minX = Math.min(minX, point.x);
      maxX = Math.max(maxX, point.x);
      minY = Math.min(minY, point.y);
      maxY = Math.max(maxY, point.y);
    });
    const x = 1 - (minX + maxX) / 2;
    const y = (minY + maxY) / 2;

    if (stage === 0) {
      const centered = x > 0.34 && x < 0.66 && y > 0.22 && y < 0.78;
      if (!centered) {
        centerSince = 0;
        setStatus('Move your face to the middle of the guide.');
        return;
      }
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
      if (!left || !right) {
        setStatus('Keep both eyes visible and look at the camera.');
        return;
      }
      const open = left.score < 0.30 && right.score < 0.30;
      const closed = left.score > 0.62 && right.score > 0.62;
      if (open) {
        openFrames++;
        if (closedEyes && openFrames >= 2) {
          closedEyes = false;
          blinkCount++;
          if (blinkCount >= 2) passStep('Two blinks detected.');
          else setStatus('Blink once more. Detected ' + blinkCount + ' of 2.');
        }
      } else if (closed && openFrames >= 2) {
        closedEyes = true;
        openFrames = 0;
        setStatus('Eyes closed. Open them to complete the blink.');
      }
      return;
    }

    if (stage === 2) {
      const nose = landmarks[1], eyeA = landmarks[33], eyeB = landmarks[263];
      if (!nose || !eyeA || !eyeB) {
        setStatus('Keep your full face visible and turn your head.');
        return;
      }
      const eyeDistance = Math.hypot(eyeA.x - eyeB.x, eyeA.y - eyeB.y);
      if (eyeDistance < 0.01) {
        setStatus('Keep your full face visible and turn your head.');
        return;
      }
      const yaw = (nose.x - (eyeA.x + eyeB.x) / 2) / eyeDistance;
      if (yaw < -0.17) {
        turnedLeft = true;
        setStatus('Left turn detected. Turn your head to the other side.');
      } else if (yaw > 0.17) {
        turnedRight = true;
        setStatus('Right turn detected. Face forward to finish.');
      } else if (turnedLeft && turnedRight && Math.abs(yaw) < 0.07) {
        passStep('Left and right head turns detected.');
      } else if (!turnedLeft) {
        setStatus('Slowly turn your head to the left.');
      } else if (!turnedRight) {
        setStatus('Now slowly turn your head to the right.');
      }
    }
  }

  function checkFrame() {
    if (!liveDialog.open || !landmarker || !livePreview.srcObject) return;
    if (livePreview.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        livePreview.currentTime !== lastVideoTime) {
      lastVideoTime = livePreview.currentTime;
      try {
        processFace(landmarker.detectForVideo(livePreview, performance.now()));
      } catch (_) {
        liveError.textContent = 'Face detection stopped. Please restart the live check.';
        stopLive();
        liveStart.hidden = false;
        liveStart.disabled = false;
        liveNext.hidden = true;
        return;
      }
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
      liveError.textContent = 'Camera access requires an HTTPS page and a supported browser.';
      liveStart.disabled = false;
      return;
    }
    try {
      liveStepText.textContent = 'Requesting camera access…';
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 840 } },
        audio: false
      });
      if (!liveDialog.open) {
        stopLive();
        return;
      }
      livePreview.srcObject = stream;
      await livePreview.play();
      liveStepText.textContent = 'Loading the on-device face detector…';
      const vision = await import('https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.2.0/vision_bundle.mjs');
      const files = await vision.FilesetResolver.forVisionTasks(wasmPath);
      landmarker = await vision.FaceLandmarker.createFromOptions(files, {
        baseOptions: { modelAssetPath: modelPath, delegate: 'CPU' },
        runningMode: 'VIDEO',
        numFaces: 1,
        outputFaceBlendshapes: true
      });
      if (!liveDialog.open) {
        stopLive();
        return;
      }
      liveStart.hidden = true;
      liveNext.hidden = false;
      liveIndicator.textContent = 'LIVE FACE CHECK';
      clearStep();
      animation = requestAnimationFrame(checkFrame);
    } catch (error) {
      stopLive();
      const denied = error && (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError');
      liveError.textContent = denied
        ? 'Camera access was denied. Allow camera access for this site in your browser settings, then try again.'
        : 'Could not start the in-page live check. Check your connection and camera permission, then try again.';
      liveStepText.textContent = 'Camera access and the on-device face detector are required to continue.';
      liveStart.disabled = false;
    }
  });

  liveNext.addEventListener('click', function () {
    if (!stagePassed) return;
    if (stage === steps.length - 1) {
      liveValue.value = '1';
      liveSlot.classList.remove('missing');
      liveStatus.textContent = 'Passed on this device';
      liveDialog.close();
      stopLive();
      return;
    }
    stage++;
    clearStep();
    liveIndicator.textContent = 'LIVE · STEP ' + (stage + 1);
  });

  function cancelLive() {
    if (liveValue.value !== '1') liveStatus.textContent = 'Not completed';
    stopLive();
    liveDialog.close();
  }
  liveCancel.addEventListener('click', cancelLive);
  liveDialog.addEventListener('cancel', function (event) {
    event.preventDefault();
    cancelLive();
  });
  liveDialog.addEventListener('close', stopLive);
  window.addEventListener('beforeunload', stopLive);

  form.addEventListener('submit', function (event) {
    const dob = form.elements.namedItem('dob').value || '';
    const day = Number(dob.slice(-2));
    if (!dob || day < 1 || day > 30) {
      event.preventDefault();
      alert('Choose a valid date of birth. The day must be between 01 and 30.');
      return;
    }
    if (liveValue.value !== '1') {
      event.preventDefault();
      liveSlot.classList.add('missing');
      liveStatus.textContent = 'Complete the live face check before submitting.';
      liveSlot.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  });
})();
