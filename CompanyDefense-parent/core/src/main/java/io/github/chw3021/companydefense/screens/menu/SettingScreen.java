package io.github.chw3021.companydefense.screens.menu;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;

public class SettingScreen implements Screen{
	private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private OrthographicCamera camera;

    private Game game;
    private TextButton createButton(String text, Skin skin, Runnable onClick) {
        TextButton button = new TextButton(text, skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run();
            }
        });
        return button;
    }

    private void addButtonToTable(Table table, TextButton button) {
        table.add(button).fillX().uniformX().pad(10);
        table.row().pad(10, 0, 10, 0);
    }

    // 버튼 및 테이블 초기화
    public void initializeButtons(Skin skin, Table table) {
        addButtonToTable(table, createButton("음량", skin, () -> {
        }));
        addButtonToTable(table, createButton("이용 약관", skin, () -> {
        }));
        addButtonToTable(table, createButton("고객 지원", skin, () -> {
            // 자동 사냥 화면으로 이동
        }));
        addButtonToTable(table, createButton("개인정보 처리 방침", skin, () -> {
            // 캐릭터/유물 정보 화면으로 이동
        }));
        addButtonToTable(table, createButton("계정 삭제", skin, () -> {
            // 뽑기 상점 화면으로 이동
        }));
    }

    
    
    public SettingScreen(Game game) {
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

        /*
      		ImageButton menuButton = new ImageButton(style);
			
			// 클릭 이벤트 설정
			menuButton.addListener(new ClickListener() {
			    @Override
			    public void clicked(InputEvent event, float x, float y) {
			        // 메뉴 화면으로 이동
			    }
			});

         */
        
        
        Table table = new Table();
        table.top().center();
        table.setFillParent(true);
        
        initializeButtons(skin, table);

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
