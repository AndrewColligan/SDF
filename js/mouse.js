import * as THREE from 'three';

let scene, camera, renderer, material, mesh, clock, uniforms, mouse, width, height;


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
        mouse: {value: new THREE.Vector2(0, 0)},
      }

    onWindowResize();
    const geometry = new THREE.PlaneGeometry(2, 2);

    fetch('shaders/vertexMouse.glsl')
        .then(response => response.text())
        .then(vertexShader => {
            fetch('shaders/fragmentMouse.glsl')
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

    mouseEvents();
    window.addEventListener('resize', onWindowResize, false);
}


function mouseEvents() {
    const sensitivity = 0.5;
    mouse = new THREE.Vector2();
    document.addEventListener('mousemove', (event)=>{
        mouse.x = event.pageX/width - sensitivity;
        mouse.y = -event.pageY/height + sensitivity;
    })
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

    if(mouse) {
        uniforms.mouse.value = mouse;
    }

    // animation loop
    requestAnimationFrame(animate);
    renderer.render(scene, camera);
}
