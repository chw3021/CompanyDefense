package io.github.chw3021.companydefense.screens.equipmentscreens;

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

import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;
import io.github.chw3021.companydefense.screens.menu.MenuScreen;

import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
public class EquipScreen implements Screen {
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private OrthographicCamera camera;

    private Game game;
    
	
	public void initializeButtons(Skin skin, Stage stage) {
	    // 화면 크기 가져오기
	    float screenWidth = Gdx.graphics.getWidth();
	    float screenHeight = Gdx.graphics.getHeight();
	
	    // Table 초기화
	    Table table = new Table();
	    table.setFillParent(true); // 화면 중앙에 Table을 채움
	    stage.addActor(table);
	
	    // 버튼 추가
	    addButtonToTable(table, createButton("메뉴", skin, () -> {
	    }), screenWidth, screenHeight);
	
	}
	
	// 버튼 추가 메서드
	private void addButtonToTable(Table table, TextButton button, float screenWidth, float screenHeight) {
	    // 버튼 높이와 여백 설정
	    float buttonHeight = screenHeight * 0.1f; // 화면 높이의 10%
	    float buttonWidth = screenWidth * 0.8f;  // 화면 너비의 80%
	
	    // Table에 버튼 추가
	    table.add(button).width(buttonWidth).height(buttonHeight).pad(10);
	    table.row().pad(10, 0, 10, 0); // 버튼 간격 설정
	}
	
	// 버튼 생성 메서드
	private TextButton createButton(String text, Skin skin, Runnable action) {
	    TextButton button = new TextButton(text, skin);
	    button.addListener(new ClickListener() {
	        @Override
	        public void clicked(InputEvent event, float x, float y) {
	            action.run();
	        }
	    });
	    return button;
	}
    
    public EquipScreen(Game game) {
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
        
        
        initializeButtons(skin, stage);

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
