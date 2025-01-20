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
        TextButton stage1Button = new TextButton("Easy", skin);
        TextButton stage2Button = new TextButton("Normal", skin);
        TextButton stage3Button = new TextButton("Hard", skin);

        stage1Button.addListener(new ClickListener() {
		    @Override
		    public void clicked(InputEvent event, float x, float y) {
                game.setScreen(new GameScreen(game, 1)); // 스테이지 1로 게임 시작
		    }
		});

        table.add(stage1Button).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
        table.add(stage2Button).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
        table.add(stage3Button).fillX().uniformX().pad(10);

        stage.addActor(table);
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
        stage.dispose();
    }

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void dispose() {
        batch.dispose();
    }
}
