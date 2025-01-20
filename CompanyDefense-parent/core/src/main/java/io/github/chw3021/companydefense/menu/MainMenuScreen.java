package io.github.chw3021.companydefense.menu;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.viewport.ScreenViewport;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
public class MainMenuScreen implements Screen {
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private OrthographicCamera camera;

    private Game game;

    public MainMenuScreen(Game game) {
        this.game = game;
        batch = new SpriteBatch();

        // 카메라 초기화
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800);
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0); // 카메라 초기 위치 설정
    }

    @Override
    public void show() {
        // Stage 초기화
        stage = new Stage(new ScreenViewport(), batch);

        // Skin과 스타일을 설정
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        Gdx.input.setInputProcessor(stage);  // Stage의 입력 처리기 설정

        Table table = new Table();
        table.top().center();
        table.setFillParent(true);

        // 버튼 생성
        TextButton startGameButton = new TextButton("GameStart", skin);
        TextButton settingsButton = new TextButton("Setting", skin);
        TextButton rankingButton = new TextButton("Ranking", skin);

        // 클릭 이벤트 설정
        startGameButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                game.setScreen(new StageSelectionScreen(game));  // 게임 시작 버튼 클릭 시 화면 전환
            }
        });

        settingsButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                // 설정 화면으로 이동 (추후 구현 가능)
            }
        });

        rankingButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                // 랭킹 화면으로 이동 (추후 구현 가능)
            }
        });

        // 버튼을 테이블에 추가
        table.add(startGameButton).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
        table.add(settingsButton).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
        table.add(rankingButton).fillX().uniformX().pad(10);

        // 테이블을 Stage에 추가
        stage.addActor(table);
    }

    @Override
    public void render(float delta) {
        // 화면 지우기
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
        stage.getViewport().update(width, height, true);  // 화면 크기 변경 시 Stage 뷰포트 업데이트
    }

    @Override
    public void hide() {
        stage.dispose();  // Stage 자원 해제
    }

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void dispose() {
        batch.dispose();  // SpriteBatch 자원 해제
    }
}
