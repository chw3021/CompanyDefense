package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Sprite;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Container;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.ScrollPane;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.screens.equipmentscreens.TowerScreenView;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreenView;
import io.github.chw3021.companydefense.screens.menu.MenuScreenPopup;
public class MainViewScreen implements Screen, LoadingListener {
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private OrthographicCamera camera;

    private Game game;

    private Container<Actor> contentContainer; // 상단 컨텐츠 교체용 컨테이너
    private ImageButton btnStage, btnAuto, btnInfo, btnShop; // 네비게이션 버튼
    private ImageButton btnMenu; // 메뉴 버튼

    private LoadingScreenManager loadingScreenManager;
    
    private Texture backgroundTexture;
    private Sprite backgroundSprite;
    
    private float screenWidth = Gdx.graphics.getWidth();
    private float screenHeight = Gdx.graphics.getHeight();

    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.showLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }

    public MainViewScreen(Game game) {
        this.game = game;
        batch = new SpriteBatch();

        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800);

        stage = new Stage(new ScreenViewport(), batch);
        Gdx.input.setInputProcessor(stage);

        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        this.loadingScreenManager = new LoadingScreenManager(stage);

        loadBackgroundImage(); // 배경 이미지 로딩

        createUI(); // UI 요소 생성
        switchScreen(new StageSelectionScreenView(game)); // 처음에는 StageSelectionScreenView 표시
    }

    /** 배경 이미지 로드 및 설정 */
    private void loadBackgroundImage() {
        backgroundTexture = new Texture(Gdx.files.internal("menu/menu_background.jpg")); // 배경 이미지 경로
        backgroundSprite = new Sprite(backgroundTexture);
        backgroundSprite.setSize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight()); // 화면 크기에 맞게 배경 사이즈 조정
    }
    private void createUI() {
        Table root = new Table();
        root.setFillParent(true);
        stage.addActor(root);

        // 💡 상단 컨텐츠를 담을 컨테이너 (페이지 전환 시 내용 변경)
        contentContainer = new Container<>();
        contentContainer.fill();
        
        // 여기에 ScrollPane을 추가하여 내용이 화면을 벗어날 경우 스크롤 가능하도록 설정
        ScrollPane scrollPane = new ScrollPane(contentContainer, skin);
        scrollPane.setFillParent(true); // ScrollPane이 부모 크기만큼 꽉 차도록 설정
        root.add(scrollPane).expand().fill().row();

        // 💡 네비게이션 바 생성
        Table navBar = new Table();
        navBar.bottom().setBackground(skin.getDrawable("black"));
        navBar.defaults().pad(10);

        btnStage = createNavButton("menu/stage.png", () -> switchScreen(new StageSelectionScreenView(game)));
        btnAuto = createNavButton("menu/auto.png", () -> System.out.println("auto"));
        btnInfo = createNavButton("menu/human.png", () -> {
            Gdx.app.postRunnable(() -> {
                switchScreen(new TowerScreenView(game));
            });
        });
        btnShop = createNavButton("menu/hobbies.png", () -> System.out.println("slotmachine"));

        navBar.add(btnStage).size(screenWidth * 0.15f);
        navBar.add(btnAuto).size(screenWidth * 0.15f);
        navBar.add(btnInfo).size(screenWidth * 0.15f);
        navBar.add(btnShop).size(screenWidth * 0.15f);

        root.add(navBar).fillX().height(screenWidth * 0.2f);

        // 💡 우측 상단 메뉴 버튼 추가
        btnMenu = createNavButton("menu/menu.png", this::showMenuPopup);
        btnMenu.setSize(screenWidth * 0.05f, screenWidth * 0.05f);
        btnMenu.setPosition(Gdx.graphics.getWidth() - screenWidth * 0.05f, Gdx.graphics.getHeight() - screenHeight * 0.05f);
        stage.addActor(btnMenu);
    }


    /** 네비게이션 버튼 생성 */
    private ImageButton createNavButton(String iconPath, Runnable onClick) {
        Texture texture = new Texture(Gdx.files.internal(iconPath));
        ImageButton button = new ImageButton(new TextureRegionDrawable(new TextureRegion(texture)));
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run();
            }
        });
        return button;
    }

    /** 💡 컨텐츠 변경 (네비게이션 화면 전환) */
    private void switchScreen(Actor newScreen) {
        // UI 요소를 비동기적으로 처리
        Gdx.app.postRunnable(() -> {
            contentContainer.setActor(newScreen);
        });
    }

    /** 💡 메뉴 팝업 띄우기 */
    private void showMenuPopup() {
        MenuScreenPopup popup = new MenuScreenPopup(skin);
        stage.addActor(popup);
    }

    @Override
    public void render(float delta) {
    	stage.setDebugAll(true);
    	
        Gdx.gl.glClearColor(0.1f, 0.1f, 0.1f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        batch.setProjectionMatrix(camera.combined);
        batch.begin();

        // 배경을 화면에 맞게 그리기
        backgroundSprite.draw(batch);

        batch.end();

        stage.act(Math.min(Gdx.graphics.getDeltaTime(), 1 / 30f));
        stage.draw();
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
    }

    @Override
    public void dispose() {
        batch.dispose();
        stage.dispose();
        skin.dispose();
        backgroundTexture.dispose(); // 배경 이미지 리소스 해제
    }

    @Override
    public void show() {}

    @Override
    public void hide() {}

    @Override
    public void pause() {}

    @Override
    public void resume() {}
}
