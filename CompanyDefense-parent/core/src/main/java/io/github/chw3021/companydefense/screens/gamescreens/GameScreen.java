package io.github.chw3021.companydefense.screens.gamescreens;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.InputMultiplexer;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.screens.LoadingScreenManager;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.stage1.Stage1;

public class GameScreen implements Screen, LoadingListener {
    private Game game;
    private SpriteBatch batch;
    private Texture background;
    private StageParent currentStage;  // 현재 스테이지를 관리하는 객체
    private FirebaseServiceImpl firebaseService; // Firebase 연동
    private ShapeRenderer shapeRenderer;

    private LoadingScreenManager loadingScreenManager;

    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.showLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }
    

    public GameScreen(Game game, int stageId) {
        this.game = game;
        this.batch = new SpriteBatch();
        this.shapeRenderer = new ShapeRenderer();
        this.firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        // 스테이지에 따라 적, 타워, 경로 등을 설정
        if (stageId == 1) {
        	currentStage = new Stage1(game);
        } else if (stageId == 2) {
            // 스테이지 2에 맞는 설정
        }
        else {
        	currentStage = new Stage1(game);
        }
        firebaseService.addLoadingListener(this);
        this.loadingScreenManager = new LoadingScreenManager(currentStage);
    }

    @Override
    public void show() {

        // InputMultiplexer 설정
        InputMultiplexer inputMultiplexer = new InputMultiplexer();
        inputMultiplexer.addProcessor(currentStage); // StageParent 자체를 InputProcessor로 설정
        Gdx.input.setInputProcessor(inputMultiplexer);
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0, 0, 0, 1); // 화면 클리어
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

//        batch.begin();
//        batch.draw(background, 0, 0); // 배경 그리기
//        batch.end();
        currentStage.render(batch, shapeRenderer);  // 선택된 스테이지 렌더링
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
