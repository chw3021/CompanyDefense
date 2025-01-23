package io.github.chw3021.companydefense.menu;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;

import io.github.chw3021.companydefense.stage.GameScreen;

import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;

public class StageSelectionScreen implements Screen {
    private Game game;
    private SpriteBatch batch;
    private Stage stage;
    private OrthographicCamera camera;
    private Skin skin;
    private boolean disposed = false;

    public StageSelectionScreen(Game game) {
        this.game = game;
        batch = new SpriteBatch();
        
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800);
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0); 
    }

    @Override
    public void show() {
        stage = new Stage();

        // Skin과 스타일을 설정
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        Gdx.input.setInputProcessor(stage);

        Table table = new Table();
        table.top().center();
        table.setFillParent(true);

        // 버튼 생성 (스테이지 1, 2, 3 버튼)
        createButton(table, "Easy", () -> game.setScreen(new GameScreen(game, 1)));
        createButton(table, "Normal", () -> game.setScreen(new GameScreen(game, 2)));
        createButton(table, "Hard", () -> game.setScreen(new GameScreen(game, 3)));

        stage.addActor(table);
    }

    // 버튼 생성 메서드
    private void createButton(Table table, String buttonText, Runnable onClick) {
        TextButton button = new TextButton(buttonText, skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run(); // 버튼 클릭 시 동작
                dispose();     // 현재 화면 리소스 정리
            }
        });
        table.add(button).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
    }
    @Override
    public void render(float delta) {
    	Gdx.gl.glClearColor(0.1f, 0.1f, 0.1f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);
        
        // 카메라 업데이트
        camera.update();

        // Stage 업데이트 및 그리기
        stage.act(Math.min(Gdx.graphics.getDeltaTime(), 1 / 30f));  // Stage의 액션 업데이트
        stage.draw();  // UI 요소 그리기
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
    }

    @Override
    public void hide() {
        dispose();
    }

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void dispose() {
        if (disposed) return; // 이미 해제된 경우 반환
        disposed = true;

        if (stage != null) stage.dispose(); // Stage 리소스 정리
        if (batch != null) batch.dispose(); // SpriteBatch 정리
        Gdx.input.setInputProcessor(null); // InputProcessor 초기화
    }
}
