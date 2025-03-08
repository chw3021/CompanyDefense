package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
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
import com.badlogic.gdx.scenes.scene2d.ui.Button;
import com.badlogic.gdx.scenes.scene2d.ui.Container;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.ScrollPane;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.Window;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.screens.equipmentscreens.HobbyScreenView;
import io.github.chw3021.companydefense.screens.equipmentscreens.TowerScreenView;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreenView;
import io.github.chw3021.companydefense.screens.imagetools.Commons;
import io.github.chw3021.companydefense.screens.menu.MenuScreenPopup;
public class MainViewScreen implements Screen, LoadingListener {
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private Skin companySkin;
    private OrthographicCamera camera;

    private Game game;

    private Container<Actor> contentContainer; // 상단 컨텐츠 교체용 컨테이너
    private ImageButton btnStage, btnAuto, btnInfo, btnHobby; // 네비게이션 버튼
    private ImageButton btnMenu; // 메뉴 버튼
    private Table topTable;
    private Table root;
    private LoadingScreenManager loadingScreenManager;
    private ScrollPane scrollPane;
    private UserDto userDto;
    private Table navBar;
    
    
    private Texture backgroundTexture;
    private Sprite backgroundSprite;
    
    private float screenWidth;
    private float screenHeight;
    
    private TowerScreenView tsv;

    private FirebaseServiceImpl firebaseService;
    
    
    private Label playerGoldLabel;
    private Label playerTimeLabel;
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

        firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        firebaseService.addLoadingListener(this);
        
        camera = new OrthographicCamera();

        stage = new Stage(new ScreenViewport(camera), batch);
        Gdx.input.setInputProcessor(stage);
        screenWidth = Gdx.graphics.getWidth();
        screenHeight = Gdx.graphics.getHeight();

        skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
        companySkin = new Skin(Gdx.files.internal("ui/companyskin.json"));
        this.loadingScreenManager = new LoadingScreenManager(stage);

        loadData();
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
    

    /** 🔹 플레이어 골드 업데이트 */
    public void updatePlayerGold() {
        Gdx.app.postRunnable(() -> playerGoldLabel.setText(" " + userDto.getGold()));
        Gdx.app.postRunnable(() -> playerTimeLabel.setText(" " + userDto.getTime()));
    }
    

    /** 🔹 플레이어 골드 업데이트 */
    public void updatePlayerGold(int gold) {
        Gdx.app.postRunnable(() -> playerGoldLabel.setText(" " + gold));
    }
    

    /** 🔹 플레이어 골드 업데이트 */
    public void updatePlayerTime(int time) {
        Gdx.app.postRunnable(() -> playerTimeLabel.setText(" " + time));
    }
    
    /** 🔹 Firebase에서 데이터 로드 */
    private void loadData() {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String existingUserId = prefs.getString("userId", null);

        if (existingUserId != null) {
            // 기존 유저 ID가 존재하면 데이터를 불러오기
            firebaseService.fetchData("users/" + existingUserId, UserDto.class, new FirebaseCallback<UserDto>() {
                @Override
                public void onSuccess(UserDto user) {
                	userDto = user;
                }

                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Login", "Failed to load existing google user", e);
                }
            });
        }
    }
    /** 🔹 상단 골드 표시 UI */
    private Table createTopBar() {
        topTable = new Table();

        topTable.setWidth(screenWidth);
        // 🔹 골드 아이콘
        Table goldTable = new Table();
        Texture goldTexture = new Texture(Gdx.files.internal("icons/coin.png"));
        Image goldIcon = new Image(new TextureRegionDrawable(new TextureRegion(goldTexture)));

        playerGoldLabel = new Label("0", skin);
        playerGoldLabel.setFontScale(screenHeight*0.001f);
        

        goldTable.add(goldIcon).size(screenWidth * 0.05f, screenWidth * 0.05f).padLeft(screenWidth * 0.01f);
        goldTable.add(playerGoldLabel).padLeft(screenWidth * 0.01f);


        // 🔹 시간 아이콘
        Table timeTable = new Table();
        Texture timeTexture = new Texture(Gdx.files.internal("icons/waste.png"));
        Image timeIcon = new Image(new TextureRegionDrawable(new TextureRegion(timeTexture)));

        playerTimeLabel = new Label("0", skin);
        playerTimeLabel.setFontScale(screenHeight*0.001f);

        timeTable.add(timeIcon).size(screenWidth * 0.05f, screenWidth * 0.05f).padLeft(screenWidth * 0.01f);
        timeTable.add(playerTimeLabel).padLeft(screenWidth * 0.01f);

        
        updatePlayerGold();
        
        topTable.add(goldTable).left().padLeft(screenWidth * 0.01f);
        topTable.add(timeTable).left().padLeft(screenWidth * 0.01f).expandX();

        // 💡 우측 상단 메뉴 버튼 추가
    	String downPath = "menu/accept.png";
        btnMenu = Commons.createImageButton("menu/menu.png", downPath,this::showMenuPopup);
        btnMenu.setSize(screenWidth * 0.05f, screenWidth * 0.05f);
        btnMenu.setPosition(Gdx.graphics.getWidth() - screenWidth * 0.05f, Gdx.graphics.getHeight() - screenHeight * 0.05f);

        topTable.add(btnMenu).size(screenWidth * 0.05f, screenWidth * 0.05f).expandX().right().pad(screenWidth * 0.005f);
        
        return topTable;
    }
    
    
    
    private void createUI() {
        root = new Table();
        root.setFillParent(true);
        stage.addActor(root);
        
        root.add(createTopBar()).center().top().width(screenWidth).row();
        
        
        // 💡 상단 컨텐츠를 담을 컨테이너 (페이지 전환 시 내용 변경)
        contentContainer = new Container<>();
        contentContainer.fill();
        contentContainer.center();
        contentContainer.setSize(screenWidth * 0.8f, screenHeight * 0.8f); // 화면 크기에 맞게 조정
        // ScrollPane 내부 크기 고정 및 스크롤바 제거
        scrollPane = new ScrollPane(contentContainer, companySkin);
        scrollPane.setScrollingDisabled(true, false); 
        scrollPane.setOverscroll(false, true);
        scrollPane.setScrollbarsVisible(false);
        scrollPane.setupFadeScrollBars(0, 0);
        scrollPane.setScrollbarsOnTop(true);

        root.add(scrollPane).expand().fill().row();

        // 💡 네비게이션 바 생성
        navBar = new Table();
        navBar.bottom().setBackground(skin.getDrawable("black"));
        navBar.defaults().pad(10);

        btnStage = createNavButton("menu/stage.png", () -> switchScreen(new StageSelectionScreenView(game)));
        btnStage.setDisabled(true);
        //btnAuto = createNavButton("menu/auto.png", () -> System.out.println("auto"));
        btnInfo = createNavButton("menu/human.png", () -> {
        	switchScreen(tsv = new TowerScreenView(game,this));
            //Gdx.app.postRunnable(() -> );
        });
        btnHobby = createNavButton("menu/hobbies.png", () -> switchScreen(new HobbyScreenView(game,this)));

        navBar.add(btnStage).size(screenWidth * 0.15f);
        //navBar.add(btnAuto).size(screenWidth * 0.15f);
        navBar.add(btnInfo).size(screenWidth * 0.15f);
        navBar.add(btnHobby).size(screenWidth * 0.15f);

        root.add(navBar).fillX().height(screenWidth * 0.2f);
        
        
        
    }

    /** 💡 컨텐츠 변경 (네비게이션 화면 전환) */
    private void switchScreen(Actor newScreen) {
        Gdx.app.postRunnable(() -> {
            newScreen.setSize(screenWidth * 0.8f, screenHeight * 0.8f); // 💡 크기 설정 유지
            contentContainer.setActor(newScreen);;
        });
    }


    /** 🔹 Stage에 리스너 추가 */
    public void addDialogListener(Window dialog) {
        ClickListener outsideClickListener = new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                // 클릭한 위치가 다이얼로그 내부가 아닐 경우 닫기
                if (dialog.getStage().hit(x, y, true).equals(dialog)) {
                    dialog.remove();
                    stage.removeListener(this); 
                }
            }
        };

        this.stage.addListener(outsideClickListener);
    }

    /** 네비게이션 버튼 생성 */
    private ImageButton createNavButton(String iconPath, Runnable onClick) {
    	String downPath = "menu/accept.png";
        ImageButton button = Commons.createImageButton(iconPath, downPath);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                onClick.run();
                if(!navBar.getChildren().isEmpty()) {
                	navBar.getChildren().forEach(child ->{
                		if(child instanceof Button) {
                			Button b = (Button) child;
                			b.setDisabled(false);
                		}
                	});
                }
                button.setDisabled(true);
            }
        });
        return button;
    }

    /** 💡 메뉴 팝업 띄우기 */
    private void showMenuPopup() {
        MenuScreenPopup popup = new MenuScreenPopup(skin, firebaseService, stage);
        stage.addActor(popup);
        addDialogListener(popup);
    }

    @Override
    public void render(float delta) {
    	
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
