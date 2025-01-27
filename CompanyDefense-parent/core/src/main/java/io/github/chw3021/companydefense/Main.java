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
import io.github.chw3021.companydefense.screens.LoginScreen;
import io.github.chw3021.companydefense.screens.MainViewScreen;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;
import io.github.chw3021.companydefense.screens.menu.MenuScreen;

public class Main extends Game implements InputProcessor{
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
    public Main() {
        firebaseService = new FirebaseServiceImpl();
        instance = this;
    }

    public Main(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
        instance = this;
    }

    public FirebaseService getFirebaseService() {
        return firebaseService;
    }
    private void createBackButton(Stage stage, Skin skin) {
        TextButton backButton = new TextButton("<", skin);
        backButton.setBounds(10, Gdx.graphics.getHeight() - 60, 100, 50); // 화면 좌상단 위치
        Main game = getInstance();
        backButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (getScreen() instanceof LoginScreen || getScreen() instanceof MainViewScreen) {
                    Gdx.app.exit();
                }
                if (getScreen() instanceof MenuScreen) {
                    setScreen(new MainViewScreen(game)); // 이전 화면으로 이동
                }
                if (getScreen() instanceof StageSelectionScreen) {
                    setScreen(new MenuScreen(game)); // 이전 화면으로 이동
                }
            }
        });
        stage.addActor(backButton);
    }
    
    @Override
    public boolean keyDown(int keycode) {
        if (keycode == Input.Keys.BACK) {
            Main game = getInstance();
            // 뒤로가기 버튼 눌렀을 때 처리
            if (getScreen() instanceof LoginScreen || getScreen() instanceof MainViewScreen) {
                Gdx.app.exit();
            }
            if (getScreen() instanceof MenuScreen) {
                setScreen(new MainViewScreen(game)); // 이전 화면으로 이동
            }
            if (getScreen() instanceof StageSelectionScreen) {
                setScreen(new MenuScreen(game)); // 이전 화면으로 이동
            }
            return true; // 처리 완료
        }
        return false; // 기본 동작으로 넘김
    }
    @Override
    public void create() {
        new SpriteBatch();
        Gdx.input.setCatchKey(Input.Keys.BACK, true);
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800); // 세로 화면 비율 (480 x 800 예제)
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0);

        new GameEngine();
        firebaseService = new FirebaseServiceImpl(); // FirebaseServiceImpl 초기화

        setScreen(new LoginScreen(this));
    }

	@Override
	public boolean keyUp(int keycode) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean keyTyped(char character) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean touchDown(int screenX, int screenY, int pointer, int button) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean touchUp(int screenX, int screenY, int pointer, int button) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean touchCancelled(int screenX, int screenY, int pointer, int button) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean touchDragged(int screenX, int screenY, int pointer) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean mouseMoved(int screenX, int screenY) {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public boolean scrolled(float amountX, float amountY) {
		// TODO Auto-generated method stub
		return false;
	}
}
