package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;

import io.github.chw3021.companydefense.stage1.Stage1;

public class GameScreen implements Screen {
    private Game game;
    private SpriteBatch batch;
    private Texture background;
    private StageParent currentStage;  // 현재 스테이지를 관리하는 객체


    public GameScreen(Game game, int stageId) {
        this.game = game;
        this.batch = new SpriteBatch();
        // 스테이지에 따라 적, 타워, 경로 등을 설정
        if (stageId == 1) {
        	currentStage = new Stage1();
        } else if (stageId == 2) {
            // 스테이지 2에 맞는 설정
        }
        else {
        	currentStage = new Stage1();
        }
    }

    @Override
    public void show() {
        currentStage.initialize();  // 선택된 스테이지 초기화

    }

    @Override
    public void render(float delta) {
        currentStage.render(batch);  // 선택된 스테이지 렌더링
    }

    @Override
    public void resize(int width, int height) {}

    @Override
    public void hide() {}

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void dispose() {
    	currentStage.dispose();  // 스테이지 리소스 해제
    }
}
