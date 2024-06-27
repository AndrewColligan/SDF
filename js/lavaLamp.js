import * as THREE from 'three';

let scene, camera, renderer, material, mesh, clock, uniforms, width, height;


init();
animate();

function init() {
    width = window.innerWidth;
    height = window.innerHeight;

    scene = new THREE.Scene();
    clock = new THREE.Clock();

    renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio( window.devicePixelRatio );
    renderer.setSize(width, height);
    document.body.appendChild(renderer.domElement);

    //camera = new THREE.PerspectiveCamera(70, w/h, 0.001, 1000);
    var frustumSize = 1;
    camera = new THREE.OrthographicCamera(frustumSize/-2, frustumSize/2, frustumSize/2, frustumSize/-2, -1000, 1000);
    camera.position.set(0, 0, 2);

    uniforms = {
        resolution: {value: new THREE.Vector4()},
        time: {value: 0.0},
      }

    onWindowResize();
    const geometry = new THREE.PlaneGeometry(2, 2);

    fetch('../shaders/vertexLavaLamp.glsl')
        .then(response => response.text())
        .then(vertexShader => {
            fetch('../shaders/fragmentLavaLamp.glsl')
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

    window.addEventListener('resize', onWindowResize, false);
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

    // animation loop
    requestAnimationFrame(animate);
    renderer.render(scene, camera);
}
