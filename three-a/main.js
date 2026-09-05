import * as THREE from 'three';

const COLORS = {
  blue: 0x3B82F6,
  green: 0x22C55E,
  red: 0xEF4444,
  wall: 0x374151,
  ink: 0x1C1C1C,
  track: 0xE8EEF5,
};
const TRACK_WIDTH = 12;
const U = TRACK_WIDTH / 280;
const PLAYER_DIAMETER = 14 * U;
const PLAYER_RADIUS = PLAYER_DIAMETER / 2;
const PLAYER_Z = 5;
const SCROLL_SPEED = 3.2;
const MAX_COUNT = 150;
const LEVEL_NUMBERS = [1, 4, 8];

const canvas = document.querySelector('#scene');
const game = document.querySelector('#game');
const hud = document.querySelector('.hud');
const countEl = document.querySelector('#count');
const levelEl = document.querySelector('#level-number');
const wallEl = document.querySelector('#wall-target');
const eventReadout = document.querySelector('#event-readout');
const tip = document.querySelector('.tip');
const menuScreen = document.querySelector('#menu-screen');
const overlay = document.querySelector('#overlay');
const resultKicker = document.querySelector('#result-kicker');
const resultTitle = document.querySelector('#result-title');
const resultCopy = document.querySelector('#result-copy');
const failActions = document.querySelector('#fail-actions');
const winActions = document.querySelector('#win-actions');
const nextButton = document.querySelector('#next');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const scene = new THREE.Scene();
scene.background = new THREE.Color(COLORS.track);
scene.fog = new THREE.Fog(COLORS.track, 24, 110);
const camera = new THREE.PerspectiveCamera(44, 1, .1, 180);
camera.position.set(0, 6.4, 15);
camera.lookAt(0, 0, -22);

scene.add(new THREE.HemisphereLight(0xffffff, 0xb6c4d4, 2.2));
const sun = new THREE.DirectionalLight(0xffffff, 3.2);
sun.position.set(8, 13, 9);
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024);
sun.shadow.camera.left = -11;
sun.shadow.camera.right = 11;
sun.shadow.camera.top = 16;
sun.shadow.camera.bottom = -6;
scene.add(sun);

const level = new THREE.Group();
scene.add(level);
const events = [];
let playerX = 0;
let count = 0;
let currentLevel = null;
let runState = 'menu';
let lastTime = performance.now();

function material(color, metalness = .16, roughness = .52) {
  return new THREE.MeshStandardMaterial({ color, metalness, roughness });
}
const inkMaterial = material(COLORS.ink, .18, .48);
const blueMaterial = material(COLORS.blue, .18, .48);
const greenMaterial = material(COLORS.green, .16, .5);
const redMaterial = material(COLORS.red, .18, .48);
const wallMaterial = material(COLORS.wall, .22, .55);
const trackMaterial = material(COLORS.track, .1, .6);

function labelSprite(text, color = '#1C1C1C', width = 2.5) {
  const labelCanvas = document.createElement('canvas');
  labelCanvas.width = 512;
  labelCanvas.height = 128;
  const context = labelCanvas.getContext('2d');
  context.clearRect(0, 0, 512, 128);
  context.fillStyle = 'rgba(255,255,255,.9)';
  context.beginPath();
  context.roundRect(8, 8, 496, 112, 28);
  context.fill();
  context.fillStyle = color;
  context.font = '900 62px Inter, Arial, sans-serif';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.fillText(text, 256, 66);
  const texture = new THREE.CanvasTexture(labelCanvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false }));
  sprite.scale.set(width, width * .25, 1);
  return sprite;
}

function addTrack() {
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(TRACK_WIDTH, 180), trackMaterial);
  floor.rotation.x = -Math.PI / 2;
  floor.position.set(0, -.72, -52);
  floor.receiveShadow = true;
  level.add(floor);
  for (const x of [-TRACK_WIDTH / 2 - .12, TRACK_WIDTH / 2 + .12]) {
    const rail = new THREE.Mesh(new THREE.BoxGeometry(.15, .22, 180), inkMaterial);
    rail.position.set(x, -.57, -52);
    rail.castShadow = true;
    level.add(rail);
  }
  for (let z = -7; z > -150; z -= 8) {
    const dash = new THREE.Mesh(new THREE.BoxGeometry(.05, .012, 2.4), new THREE.MeshStandardMaterial({ color: 0xcbd6e2, roughness: .7 }));
    dash.position.set(0, -.705, z);
    level.add(dash);
  }
}

function gateParts(label, colorMaterial, stroke, fake = false) {
  const group = new THREE.Group();
  const width = 120 * U;
  const height = 56 * U;
  const depth = 12 * U;
  const sideGeometry = new THREE.BoxGeometry(stroke, height, depth);
  const topGeometry = new THREE.BoxGeometry(width, stroke, depth);
  const left = new THREE.Mesh(sideGeometry, colorMaterial);
  const right = new THREE.Mesh(sideGeometry, colorMaterial);
  const top = new THREE.Mesh(topGeometry, colorMaterial);
  left.position.x = -(width - stroke) / 2;
  right.position.x = (width - stroke) / 2;
  top.position.y = height / 2 - stroke / 2;
  for (const part of [left, right, top]) {
    part.castShadow = true;
    group.add(part);
  }
  if (fake) {
    const notch = new THREE.Mesh(new THREE.BoxGeometry(16 * U, 16 * U, depth), colorMaterial);
    notch.position.set(width / 2 - 8 * U, height / 2 - 8 * U, 0);
    notch.castShadow = true;
    group.add(notch);
  }
  const sign = labelSprite(label, colorMaterial === redMaterial ? '#991b1b' : '#166534', 3.2);
  sign.position.set(0, height / 2 + .52, 0);
  group.add(sign);
  return group;
}

function makeGate(label, z, operation, value, options = {}) {
  const gate = gateParts(label, options.red ? redMaterial : greenMaterial, options.red ? 12 * U : 8 * U, options.fake);
  gate.position.set(options.x || 0, .45, z);
  gate.userData = { kind: 'gate', operation, value, label, done: false };
  level.add(gate);
  events.push(gate);
}

function makeFork(z, left, right) {
  const fork = new THREE.Group();
  const leftGate = gateParts(left.label, left.red ? redMaterial : greenMaterial, left.red ? 12 * U : 8 * U, left.fake);
  const rightGate = gateParts(right.label, right.red ? redMaterial : greenMaterial, right.red ? 12 * U : 8 * U, right.fake);
  leftGate.position.x = -3.45;
  rightGate.position.x = 3.45;
  fork.add(leftGate, rightGate);
  const leftHint = labelSprite('LEFT', '#991b1b', 1.8);
  leftHint.position.set(-3.45, 3.15, 0);
  const rightHint = labelSprite('RIGHT', '#166534', 1.8);
  rightHint.position.set(3.45, 3.15, 0);
  fork.add(leftHint, rightHint);
  fork.position.set(0, .45, z);
  fork.userData = { kind: 'fork', left, right, done: false };
  level.add(fork);
  events.push(fork);
}

function makeSaw(z, value) {
  const saw = new THREE.Group();
  const radius = 36 * U;
  const hub = new THREE.Mesh(new THREE.CylinderGeometry(radius * .48, radius * .48, 10 * U, 24), redMaterial);
  hub.rotation.x = Math.PI / 2;
  hub.castShadow = true;
  saw.add(hub);
  const toothGeometry = new THREE.BoxGeometry(.16, .42, .14);
  for (let i = 0; i < 12; i += 1) {
    const angle = i / 12 * Math.PI * 2;
    const tooth = new THREE.Mesh(toothGeometry, inkMaterial);
    tooth.position.set(Math.cos(angle) * radius * .9, Math.sin(angle) * radius * .9, 0);
    tooth.rotation.z = angle;
    tooth.castShadow = true;
    saw.add(tooth);
  }
  const label = `SAW ${value < 0 ? '−' : '+'}${Math.abs(value)} · FULL WIDTH`;
  const sign = labelSprite(label, '#991b1b', 3.9);
  sign.position.set(0, radius + .75, 0);
  saw.add(sign);
  saw.position.set(0, .05, z);
  saw.userData = { kind: 'saw', value, label, done: false };
  level.add(saw);
  events.push(saw);
}

function makeTide(z, value) {
  const tide = new THREE.Group();
  const band = new THREE.Mesh(new THREE.BoxGeometry(280 * U, 18 * U, 16 * U), redMaterial);
  band.position.y = -.05;
  band.castShadow = true;
  tide.add(band);
  const label = `TIDE ${value < 0 ? '−' : '+'}${Math.abs(value)} · FULL WIDTH`;
  const sign = labelSprite(label, '#991b1b', 4.7);
  sign.position.set(0, 18 * U / 2 + .55, 0);
  tide.add(sign);
  tide.position.set(0, .15, z);
  tide.userData = { kind: 'tide', value, label, done: false };
  level.add(tide);
  events.push(tide);
}

function makeWall(z, target) {
  const wall = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(280 * U, 40 * U, 20 * U), wallMaterial);
  body.position.y = -.05;
  body.castShadow = true;
  body.receiveShadow = true;
  wall.add(body);
  const sign = labelSprite(`WALL ${target} · NEED > ${target}`, '#ffffff', 4.7);
  sign.position.set(0, 40 * U / 2 + .55, 0);
  wall.add(sign);
  wall.position.set(0, .15, z);
  wall.userData = { kind: 'wall', value: target, label: `WALL ${target}`, done: false };
  level.add(wall);
  events.push(wall);
}

function makeStart(startCount) {
  const start = new THREE.Group();
  const sign = labelSprite(`START · COUNT ${startCount}`, '#1d4ed8', 3.6);
  sign.position.set(0, .9, 0);
  start.add(sign);
  const stripe = new THREE.Mesh(new THREE.BoxGeometry(TRACK_WIDTH, .025, .18), blueMaterial);
  stripe.position.y = -.69;
  start.add(stripe);
  start.position.z = 8;
  level.add(start);
}

function makePlayer() {
  const bean = new THREE.Mesh(new THREE.SphereGeometry(PLAYER_RADIUS, 28, 18), blueMaterial);
  bean.scale.y = 1.08;
  bean.position.set(0, -.18, PLAYER_Z);
  bean.castShadow = true;
  scene.add(bean);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(PLAYER_RADIUS * 1.22, .025, 8, 32), blueMaterial);
  ring.rotation.x = Math.PI / 2;
  ring.position.set(0, -.68, PLAYER_Z);
  scene.add(ring);
  return { bean, ring };
}

const levelDefinitions = {
  1: {
    start: 5,
    wall: 20,
    events: [
      { type: 'gate', z: -5, label: '+5', operation: 'add', value: 5 },
      { type: 'gate', z: -28, label: '×2', operation: 'multiply', value: 2 },
      { type: 'saw', z: -52, value: -3 },
      { type: 'gate', z: -76, label: '+10', operation: 'add', value: 10 },
    ],
  },
  4: {
    start: 8,
    wall: 50,
    events: [
      { type: 'gate', z: -5, label: '×2', operation: 'multiply', value: 2 },
      { type: 'fork', z: -28, left: { label: '−10', operation: 'subtract', value: 10, red: true }, right: { label: '+15', operation: 'add', value: 15 } },
      { type: 'tide', z: -54, value: -12 },
      { type: 'gate', z: -80, label: '×3', operation: 'multiply', value: 3 },
      { type: 'saw', z: -104, value: -5 },
    ],
  },
  8: {
    start: 10,
    wall: 120,
    events: [
      { type: 'gate', z: -5, label: '+20', operation: 'add', value: 20 },
      { type: 'fork', z: -28, left: { label: '×3', operation: 'multiply', value: 3 }, right: { label: '×5', operation: 'add', value: -20, fake: true, red: true } },
      { type: 'saw', z: -54, value: -5 },
      { type: 'saw', z: -76, value: -5 },
      { type: 'tide', z: -98, value: -25 },
      { type: 'gate', z: -124, label: '×2', operation: 'multiply', value: 2 },
      { type: 'gate', z: -148, label: '+30', operation: 'add', value: 30 },
    ],
  },
};

function clearLevel() {
  while (level.children.length) level.remove(level.children[0]);
  events.length = 0;
}

function buildLevel(levelNumber) {
  clearLevel();
  const definition = levelDefinitions[levelNumber];
  currentLevel = levelNumber;
  count = definition.start;
  level.position.z = 0;
  addTrack();
  makeStart(definition.start);
  for (const event of definition.events) {
    if (event.type === 'gate') makeGate(event.label, event.z, event.operation, event.value);
    if (event.type === 'fork') makeFork(event.z, event.left, event.right);
    if (event.type === 'saw') makeSaw(event.z, event.value);
    if (event.type === 'tide') makeTide(event.z, event.value);
  }
  makeWall(-174, definition.wall);
  updateHud('GET READY');
}

function updateHud(message = 'DRAG TO MOVE') {
  countEl.textContent = String(count);
  levelEl.textContent = String(currentLevel || '—');
  wallEl.textContent = currentLevel ? `> ${levelDefinitions[currentLevel].wall}` : '—';
  eventReadout.textContent = message;
}

function setPlayerX(nextX) {
  playerX = THREE.MathUtils.clamp(nextX, -TRACK_WIDTH / 2 + PLAYER_RADIUS, TRACK_WIDTH / 2 - PLAYER_RADIUS);
  player.bean.position.x = playerX;
  player.ring.position.x = playerX;
}

function applyOperation(value, operation, operand) {
  if (operation === 'add') value += operand;
  if (operation === 'subtract') value -= operand;
  if (operation === 'multiply') value *= operand;
  if (operation === 'divide') value = operand === 0 ? value : value / operand;
  return THREE.MathUtils.clamp(value, 0, MAX_COUNT);
}

function showMenu() {
  runState = 'menu';
  currentLevel = null;
  clearLevel();
  overlay.classList.remove('show');
  menuScreen.classList.add('show');
  hud.classList.add('hidden');
  tip.classList.add('hidden');
  updateHud('SELECT A LEVEL');
}

function startLevel(levelNumber) {
  buildLevel(levelNumber);
  runState = 'playing';
  menuScreen.classList.remove('show');
  hud.classList.remove('hidden');
  tip.classList.remove('hidden');
  overlay.classList.remove('show');
  setPlayerX(0);
}

function restart() {
  if (!currentLevel) return;
  startLevel(currentLevel);
  updateHud('GET READY');
}

function finish(won) {
  runState = won ? 'won' : 'failed';
  resultKicker.textContent = `MODE A · LEVEL ${currentLevel}`;
  resultTitle.textContent = won ? 'LEVEL CLEAR' : 'RUN FAILED';
  resultCopy.textContent = won
    ? `You reached ${count}. The wall needed more than ${levelDefinitions[currentLevel].wall}.`
    : `The wall held at ${count}. Tap to try Level ${currentLevel} again.`;
  failActions.classList.toggle('hidden', won);
  winActions.classList.toggle('hidden', !won);
  nextButton.textContent = currentLevel === 8 ? 'MENU' : 'NEXT';
  overlay.classList.add('show');
}

function applyEvent(event) {
  const data = event.userData;
  data.done = true;
  if (data.kind === 'gate') {
    count = applyOperation(count, data.operation, data.value);
    updateHud(data.label);
    return;
  }
  if (data.kind === 'fork') {
    const option = playerX < 0 ? data.left : data.right;
    count = applyOperation(count, option.operation, option.value);
    updateHud(`${playerX < 0 ? 'LEFT' : 'RIGHT'} · ${option.label}`);
    return;
  }
  if (data.kind === 'saw' || data.kind === 'tide') {
    count = applyOperation(count, 'add', data.value);
    updateHud(data.label);
    return;
  }
  if (data.kind === 'wall') {
    updateHud(data.label);
    finish(count > data.value);
  }
}

function tick(time) {
  const delta = Math.min((time - lastTime) / 1000, .05);
  lastTime = time;
  if (runState === 'playing') {
    level.position.z += SCROLL_SPEED * delta;
    player.bean.rotation.y += delta * 1.8;
    player.ring.rotation.z -= delta * 1.2;
    for (const event of events) {
      const worldZ = event.position.z + level.position.z;
      if (!event.userData.done && worldZ >= PLAYER_Z - .45) applyEvent(event);
    }
  }
  renderer.render(scene, camera);
  requestAnimationFrame(tick);
}

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
}

let dragging = false;
let lastPointerX = 0;
canvas.addEventListener('pointerdown', (event) => {
  dragging = true;
  lastPointerX = event.clientX;
  canvas.setPointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointermove', (event) => {
  if (!dragging || runState !== 'playing') return;
  const delta = event.clientX - lastPointerX;
  lastPointerX = event.clientX;
  setPlayerX(playerX + delta / window.innerWidth * TRACK_WIDTH * 1.8);
});
canvas.addEventListener('pointerup', () => { dragging = false; });
canvas.addEventListener('pointercancel', () => { dragging = false; });
window.addEventListener('keydown', (event) => {
  if (runState !== 'playing') return;
  if (event.key === 'ArrowLeft' || event.key.toLowerCase() === 'a') { event.preventDefault(); setPlayerX(playerX - .55); }
  if (event.key === 'ArrowRight' || event.key.toLowerCase() === 'd') { event.preventDefault(); setPlayerX(playerX + .55); }
});
document.querySelectorAll('[data-level]').forEach((button) => {
  button.addEventListener('click', () => startLevel(Number(button.dataset.level)));
});
document.querySelector('#fail-restart').addEventListener('click', restart);
nextButton.addEventListener('click', () => {
  const nextIndex = LEVEL_NUMBERS.indexOf(currentLevel) + 1;
  if (nextIndex >= LEVEL_NUMBERS.length) showMenu();
  else startLevel(LEVEL_NUMBERS[nextIndex]);
});
document.querySelector('#menu').addEventListener('click', showMenu);
window.addEventListener('resize', resize);
const player = makePlayer();
resize();
showMenu();
requestAnimationFrame(tick);
