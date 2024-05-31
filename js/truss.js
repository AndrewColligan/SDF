import * as THREE from 'three';

let scene, camera, renderer, material, mesh, clock, uniforms, width, height;

let rotationX = 0;
let rotationY = 0;
let isPanning = false;
let isRotating = false;
let lastMouseX = 0;
let lastMouseY = 0;
let cameraAdjPos = new THREE.Vector3(0.0, 0.0, 0.0);

init();
animate();


function init() {
    width = window.innerWidth;
    height = window.innerHeight;

    scene = new THREE.Scene();
    clock = new THREE.Clock();

    renderer = new THREE.WebGLRenderer();
    renderer.setSize(width, height);
    document.body.appendChild(renderer.domElement);

    var frustumSize = 1;
    camera = new THREE.OrthographicCamera(frustumSize/-2, frustumSize/2, frustumSize/2, frustumSize/-2, -1000, 1000);
    camera.position.set(0, 0, 2);

    uniforms = {
        resolution: {value: new THREE.Vector4()},
        time: {value: 0.0},
        u_rotationX: {value: 0.0},
        u_rotationY: {value: 0.0},
        cameraAdjPos: {value: new THREE.Vector3(0.0, 0.0, 0.0)},
        matcap: {value: new THREE.TextureLoader().load('../imgs/metalMatcap.jpg')},
      }

    onWindowResize();
    const geometry = new THREE.PlaneGeometry(2, 2);

    fetch('../shaders/vertexTruss.glsl')
        .then(response => response.text())
        .then(vertexShader => {
            fetch('../shaders/fragmentTruss.glsl')
                .then(response => response.text())
                .then(fragmentShader => {
                    material = new THREE.ShaderMaterial({
                        uniforms: uniforms,
                        vertexShader: vertexShader,
                        fragmentShader: fragmentShader
                    });

                    mesh = new THREE.Mesh(geometry, material);
                    scene.add(mesh);

                    animate();
                });
        });

    mouseMoveEvents();
    mouseWheelEvents();
    window.addEventListener('resize', onWindowResize, false);
}


function mouseMoveEvents() {
    document.addEventListener('mousedown', (event) => {
        if (event.button === 0) {  // Left mouse button
            isRotating = true;
        } else if (event.button === 1) {  // Middle mouse button
            isRotating = true;
        } else if (event.button === 2) {  // Right mouse button
            isPanning = true;
        }
        lastMouseX = event.clientX;
        lastMouseY = event.clientY;
    });

    document.addEventListener('mouseup', () => {
        isRotating = false;
        isPanning = false;
    });

    document.addEventListener('mousemove', (event) => {
        if (isRotating) {
            const rotSensitivity = 0.01;
            const deltaX = event.clientX - lastMouseX;
            const deltaY = event.clientY - lastMouseY;
            rotationX += deltaY * rotSensitivity;
            rotationY += deltaX * rotSensitivity;
            lastMouseX = event.clientX;
            lastMouseY = event.clientY;
        } else if (isPanning) {
            const panSensitivity = 0.002;
            const deltaX = event.clientX - lastMouseX;
            const deltaY = event.clientY - lastMouseY;
            cameraAdjPos.x -= deltaX * panSensitivity;
            cameraAdjPos.y += deltaY * panSensitivity;
            lastMouseX = event.clientX;
            lastMouseY = event.clientY;
        }
    });
}


function mouseWheelEvents() {
    document.addEventListener('wheel', (event) => {
        const scrollSensitivity = 0.002;
        cameraAdjPos.z += event.deltaY * scrollSensitivity;
    });
}


function onWindowResize() {
    width = window.innerWidth;
    height = window.innerHeight;
    renderer.setSize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();

    const imageAspect = 1;
    let a1; let a2;
    if(height/width>imageAspect) {
        a1 = (width/height) * imageAspect;
        a2 = 1;
    } else {
        a1 = 1;
        a2 = (height/width) / imageAspect;
    }

    uniforms.resolution.value.x = width;
    uniforms.resolution.value.y = height;
    uniforms.resolution.value.z = a1;
    uniforms.resolution.value.w = a2;
}

function animate() {
    // update time uniform
    uniforms.time.value = clock.getElapsedTime();

    // Update shader uniforms
    uniforms.u_rotationX.value = rotationX;
    uniforms.u_rotationY.value = rotationY;
    uniforms.cameraAdjPos.value = cameraAdjPos;


    // animation loop
    requestAnimationFrame(animate);
    renderer.render(scene, camera);
}
