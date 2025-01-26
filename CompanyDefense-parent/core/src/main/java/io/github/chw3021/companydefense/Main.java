package io.github.chw3021.companydefense;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;

import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.menu.LoginScreen;

public class Main extends Game {
    private OrthographicCamera camera;

    private FirebaseService firebaseService;

    private static Main instance;

    public static Main getInstance() {
        if (instance == null) {
            throw new IllegalStateException("Main instance is not initialized yet.");
        }
        return instance;
    }

    // 기본 생성자 (필요한 경우 사용)
    public Main() {}

    public Main(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
        instance = this;
    }

    public FirebaseService getFirebaseService() {
        return firebaseService;
    }

    @Override
    public void create() {
        new SpriteBatch();
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800); // 세로 화면 비율 (480 x 800 예제)
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0);

        new GameEngine();
        firebaseService = new FirebaseServiceImpl(); // FirebaseServiceImpl 초기화
        setScreen(new LoginScreen(this));
    }
}
