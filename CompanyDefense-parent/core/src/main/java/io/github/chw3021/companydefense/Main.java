package io.github.chw3021.companydefense;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;

import io.github.chw3021.companydefense.menu.MainMenuScreen;
import io.github.chw3021.companydefense.menu.StageSelectionScreen;

/** {@link com.badlogic.gdx.ApplicationListener} implementation shared by all platforms. */
public class Main extends Game {
    private OrthographicCamera camera;

    private static Main instance;

    public static Main getInstance() {
        if (instance == null) {
            instance = new Main();
        }
        return instance;
    }
    
    
    @Override
    public void create() {
        new SpriteBatch();
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800); // 세로 화면 비율 (480 x 800 예제)
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0);

        new GameEngine();
        setScreen(new MainMenuScreen(this));
    }
    

}