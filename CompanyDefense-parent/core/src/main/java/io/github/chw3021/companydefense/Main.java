package io.github.chw3021.companydefense;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.InputProcessor;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;

import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.platform.GoogleSignInHandler;
import io.github.chw3021.companydefense.screens.LoginScreen;
import io.github.chw3021.companydefense.screens.MainViewScreen;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;

public class Main extends Game implements InputProcessor {
    private OrthographicCamera camera;
    private FirebaseService firebaseService;
    private GoogleSignInHandler googleSignInHandler; // ✅ GoogleSignInHandler 추가
    private static Main instance;

    public static Main getInstance() {
        if (instance == null) {
            throw new IllegalStateException("Main instance is not initialized yet.");
        }
        return instance;
    }

    // 기본 생성자
    public Main() {
        this.firebaseService = new FirebaseServiceImpl();
        this.googleSignInHandler = null;  // 기본 생성자에서는 null 처리
        instance = this;
    }

    // GoogleSignInHandler를 받는 생성자 추가
    public Main(FirebaseService firebaseService, GoogleSignInHandler googleSignInHandler) {
        this.firebaseService = firebaseService;
        this.googleSignInHandler = googleSignInHandler;
        instance = this;
    }

    // GoogleSignInHandler Getter 추가
    public GoogleSignInHandler getGoogleSignInHandler() {
        return googleSignInHandler;
    }

    public FirebaseService getFirebaseService() {
        return firebaseService;
    }

    private void createBackButton(Stage stage, Skin skin) {
        TextButton backButton = new TextButton("<", skin);
        backButton.setBounds(10, Gdx.graphics.getHeight() - 60, 100, 50);
        Main game = getInstance();
        backButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (getScreen() instanceof LoginScreen || getScreen() instanceof MainViewScreen) {
                    Gdx.app.exit();
                }
            }
        });
        stage.addActor(backButton);
    }

    @Override
    public void create() {
        new SpriteBatch();
        Gdx.input.setCatchKey(Input.Keys.BACK, true);
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 900, 1600);
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0);

        new GameEngine();
        firebaseService = new FirebaseServiceImpl();

        setScreen(new LoginScreen(this, googleSignInHandler));
    }

    @Override
    public boolean keyDown(int keycode) {
        if (keycode == Input.Keys.BACK) {
            Main game = getInstance();
            if (getScreen() instanceof LoginScreen || getScreen() instanceof MainViewScreen) {
                Gdx.app.exit();
            }
            return true;
        }
        return false;
    }

    @Override
    public boolean keyUp(int keycode) { return false; }
    @Override
    public boolean keyTyped(char character) { return false; }
    @Override
    public boolean touchDown(int screenX, int screenY, int pointer, int button) { return false; }
    @Override
    public boolean touchUp(int screenX, int screenY, int pointer, int button) { return false; }
    @Override
    public boolean touchCancelled(int screenX, int screenY, int pointer, int button) { return false; }
    @Override
    public boolean touchDragged(int screenX, int screenY, int pointer) { return false; }
    @Override
    public boolean mouseMoved(int screenX, int screenY) { return false; }
    @Override
    public boolean scrolled(float amountX, float amountY) { return false; }
}
