package io.github.chw3021.companydefense.stage;

import java.util.HashMap;
import java.util.List;
import java.util.concurrent.CountDownLatch;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Circle;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.Touchable;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Align;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.screens.LoadingScreenManager;
import io.github.chw3021.companydefense.screens.imagetools.Commons;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class StageParent extends Stage implements LoadingListener{
	protected Game game;
    
	protected float[][] map; // 맵 데이터 (0: 장애물)
	protected float startX;
	protected float startY;
	protected float endX;
	protected float endY;
    protected WaveManager waveManager;
    protected Array<Enemy> activeEnemies;
    public Array<Tower> towers;
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected Array<Obstacle> pathVisuals;
    protected float offsetY = 0;
    protected AStarPathfinding aStar;  // AStar 경로 탐색
    protected int life = 8;  // 초기 Life 설정

    // 맵의 크기 (gridWidth, gridHeight)
    public int mapWidth;  // 예시: 맵의 가로 크기
    public int mapHeight; // 예시: 맵의 세로 크기
    public int gridSize;
    // 소환할 수 있는 타워 리스트
    public Array<Tower> availableTowers;
    private Array<Vector2> spawnablePositions;

    protected Texture obstacleTexture;
    protected Texture pathTexture;
    protected Texture backgroundTexture;
    protected Texture focusTexture, focusTexture2;

    private Skin skin;
    private Label lifeLabel; // Life를 표시하는 Label
    private Table uiTable; // UI 구성
    private Label coinLabel;
    private int currency = 100000; // 초기 재화 값 (필요시 업데이트)
    public Table towerInfoTable;

	private Table towerImageTable;
    private Label towerNameLabel, attackPowerLabel, towerPriceLabel, hrLabel, dvLabel, slLabel;
    private Label hrUpgradeCost,dvUpgradeCost,slUpgradeCost;
    private Image towerImage;
    private Tower selectedTower = null;
    private StageParent stage = this;
    
    private HashMap<String, Integer> teamLevel = new HashMap<String, Integer>();

	private float uiTableElsize;

	
    private LoadingScreenManager loadingScreenManager;
    
    // 소환 가능한 타워의 영역을 확인
    protected boolean canSpawnTowerAt(float x, float y) {
        for (Tower tower : towers) {
            if (tower.getPosition().x == x && tower.getPosition().y == y) {
                return false;
            }
        }

        return true; 
    }
    
    // 타워 소환 메서드
    public void spawnTower() {
        Array<Vector2> filteredPositions = new Array<>();
        for (Vector2 position : spawnablePositions) {
            if (canSpawnTowerAt(position.x, position.y)) {
                filteredPositions.add(position);
            }
        }
        if(currency-100<0) {
            System.out.println("money!");
        	return;
        }

        if (filteredPositions.size > 0) {
            Vector2 selectedPosition = filteredPositions.random();

            // 타워 배치
            Tower towerToSpawn = new Tower(availableTowers.random());
            towerToSpawn.setPosition(selectedPosition);
            towerToSpawn.setTouchable(Touchable.enabled);
            towerToSpawn.setSize(gridSize * 0.8f, gridSize * 0.8f);
            towerToSpawn.setPhysicalAttack(towerToSpawn.getBasePhysicalAttack() * (1.05f + 0.05f*teamLevel.get(towerToSpawn.getTeam())));
            towerToSpawn.setMagicAttack(towerToSpawn.getBaseMagicAttack() * (1.05f + 0.05f*teamLevel.get(towerToSpawn.getTeam())));
            this.addActor(towerToSpawn);
            towers.add(towerToSpawn);
            currency -= 100;

        } else {
            System.out.println("No valid positions to spawn a tower!");
        }
    }

	public Enemy generateEnemy(float health, float physicalDefense, 
			float magicDefense, float moveSpeed, String type, String path) {
		return new Enemy(startX* gridSize, startY* gridSize+offsetY,  // start position
			health, physicalDefense, magicDefense,        // health, physical/magic defense 
			moveSpeed*gridSize,              // move speed
			type,         // type
			path, 
			new Vector2(endX * gridSize, (endY * gridSize)+offsetY),
			this,
			map
	    );
	}

	private void initializeSpawnablePositions() {
	    spawnablePositions = new Array<>();
	    for (int y = 0; y < mapHeight; y++) {
	        for (int x = 0; x < mapWidth; x++) {
	            if (map[y][x] == 0.0f) {
	                float adjustedY = offsetY + y * gridSize;
	                spawnablePositions.add(new Vector2(x * gridSize, adjustedY));
	            }
	        }
	    }
	}
	
    public StageParent(Game game) {
        super();
        
        this.loadingScreenManager = new LoadingScreenManager(this);
        FirebaseServiceImpl firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        firebaseService.addLoadingListener(this);
        
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
        towers = new Array<>();

        activeEnemies = new Array<>();
        waveManager = new WaveManager(this, game);
        availableTowers = new Array<>();
        
    }
    

    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.showLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }
    
    @Override
    public void draw() {
    	super.draw();
    }
    
    @Override
    public void act(float delta) {
        super.act(delta);
        if (waveManager.isGameOver() || waveManager.isGameWon()) {
            // 게임이 종료되었으면 더 이상 업데이트하지 않음
            return;
        }
        // Update enemies
        for (Enemy enemy : new Array.ArrayIterator<>(activeEnemies)) {
        	if(enemy == null) {
        		return;
        	}
            enemy.update();
            
        }
        // 타워 공격 로직 추가
        for (Tower tower : towers) {
            tower.update(delta, activeEnemies); // 타워가 범위 내 적을 공격
        }
        lifeLabel.setText(life);
        coinLabel.setText(currency);

        // Update wave management
        waveManager.update(delta, this);
        waveManager.checkGameOver(this);
        
    }

    public Array<Enemy> getActiveEnemies() {
        return activeEnemies;
    }
    public void setLife(int life) {
        this.life = life;
    }
    
	private Table createUpgradeButton(String labelText, String iconUp, String iconDown, String teamName) {
	    ImageButton button = Commons.createImageButton(iconUp, iconDown, new ClickListener() {
	        @Override
	        public void clicked(InputEvent event, float x, float y) {
	            upgradeTeamTowers(teamName);
	        }
	    });
	    teamLevel.put(teamName, 1);

	    Label label = new Label(labelText, skin);
	    if (teamName.equals("hr")) {
	    	hrLabel = label;
	    	hrUpgradeCost = new Label("50", skin);
	    	hrUpgradeCost.setColor(Color.GOLD);
	    	hrUpgradeCost.setFontScale(uiTableElsize*0.015f);
	    	hrUpgradeCost.setAlignment(Align.right); // 왼쪽 정렬
	    }
	    if (teamName.equals("dv")) {
	    	dvLabel = label;
	    	dvUpgradeCost = new Label("50", skin);
	    	dvUpgradeCost.setColor(Color.GOLD);
	    	dvUpgradeCost.setFontScale(uiTableElsize*0.015f);
	    	dvUpgradeCost.setAlignment(Align.right); // 왼쪽 정렬
	    }
	    if (teamName.equals("sl")) {
	    	slLabel = label;
	    	slUpgradeCost = new Label("50", skin);
	    	slUpgradeCost.setColor(Color.GOLD);
	    	slUpgradeCost.setFontScale(uiTableElsize*0.015f);
	    	slUpgradeCost.setAlignment(Align.right); // 왼쪽 정렬
	    }
    	label.setText(labelText+" Lv."+teamLevel.get(teamName));

	    label.setStyle(Commons.createLabelStyleWithBackground(label, skin));
	    label.setAlignment(Align.left); // 왼쪽 정렬
	    label.setFontScale(uiTableElsize*0.015f); // 텍스트 크기 조정

	    // Table을 사용하여 Label과 Button을 나란히 배치
	    Table table = new Table();
	    table.add(label).left().padLeft(10);  // 라벨을 왼쪽에 배치, 오른쪽 여백 추가
	    table.add(button).width(uiTableElsize).height(uiTableElsize).right().padRight(5); // 버튼 크기 지정

	    return table;
	}

    private void upgradeTeamTowers(String teamName) {
        int cost = 50*teamLevel.get(teamName); // 업그레이드 비용 (원하는 값으로 설정)
	     if (teamName.equals("hr")) hrUpgradeCost.setText(cost);
	     if (teamName.equals("dv")) dvUpgradeCost.setText(cost);
	     if (teamName.equals("sl")) slUpgradeCost.setText(cost);
        
        if (currency < cost) {
            System.out.println("재화 부족!");
            return;
        }
        currency -= cost; // 재화 차감
        teamLevel.computeIfPresent(teamName, (k,v) -> v=v+1);

        for (Tower tower : towers) {
            if (tower.getTeam().equals(teamName)) {
            	upgradeTowerByTeamLevel(tower, teamName);
            }
        }

        updateUpgradeLabel(teamName);
    }
    
    public void upgradeTowerByTeamLevel(Tower tower, String teamName) {
        tower.setPhysicalAttack(tower.getBasePhysicalAttack() * (1.05f + 0.05f*teamLevel.get(teamName)));
        tower.setMagicAttack(tower.getBaseMagicAttack() * (1.05f + 0.05f*teamLevel.get(teamName)));
    }
    

	 // 업그레이드 레벨 UI 업데이트
	 private void updateUpgradeLabel(String teamName) {
	     int level = teamLevel.get(teamName);
	     String text = teamName.equals("hr") ? "인사" : teamName.equals("dv") ? "개발" : "영업";
	     String newText = text + " Lv." + level;
	     
	     // 해당 버튼의 Stack 안에 있는 Label을 찾아서 텍스트 변경
	     if (teamName.equals("hr")) hrLabel.setText(newText);
	     if (teamName.equals("dv")) dvLabel.setText(newText);
	     if (teamName.equals("sl")) slLabel.setText(newText);
	 }
    
	 private Table createCostTable(Label label) {
		    Table table = new Table();
		    table.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))).width(uiTableElsize*0.5f).height(uiTableElsize*0.5f); // 버튼 크기 지정
		    table.add(label).padLeft(5);
		    return table;
	 }

	 
    public void initialize() {

        ImageButton waveButton = Commons.createImageButton("icons/start-button.png", "icons/start-button_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                waveManager.startNextWave();
            }
        });

        ImageButton spawnButton = Commons.createImageButton("icons/work.png", "icons/work_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                spawnTower();
            }
        });

        float screenWidth = Gdx.graphics.getWidth();
        float screenHeight = Gdx.graphics.getHeight();
        uiTableElsize = screenWidth * 0.1f; // 버튼 크기 축소
        
        
        coinLabel = new Label(null, skin);
        coinLabel.setStyle(Commons.createLabelStyleWithBackground(coinLabel, skin));
        coinLabel.setFontScale(uiTableElsize*0.02f); // 폰트 크기 축소
        coinLabel.setColor(Color.GOLD);

		// 버튼 생성
		Table hrUpgrade = createUpgradeButton("인사", "icons/hrup.png", "icons/hrup_down.png", "hr");
		Table dvUpgrade = createUpgradeButton("개발", "icons/dvup.png", "icons/dvup_down.png", "dv");
		Table slUpgrade = createUpgradeButton("영업", "icons/slup.png", "icons/slup_down.png", "sl");

		Table coinStack = new Table();
        coinStack.add(new Image(new Texture(Gdx.files.internal("icons/coin.png"))));
        coinStack.add(coinLabel).pad(uiTableElsize*0.02f);

        Table lifeStack = new Table();
        // Life Label과 하트 이미지 생성
        Texture heartTexture = new Texture(Gdx.files.internal("icons/heart.png"));
        Image heartImage = new Image(heartTexture);
        lifeLabel = new Label(null, skin);
        lifeLabel.setStyle(Commons.createLabelStyleWithBackground(lifeLabel, skin));
        lifeLabel.setFontScale(uiTableElsize*0.02f); // 텍스트 크기 조정
        lifeStack.add(heartImage);
        lifeStack.add(lifeLabel).pad(uiTableElsize*0.02f);
        
        uiTable = new Table();
        uiTable.setWidth(screenWidth);
        uiTable.setHeight(screenHeight-mapHeight*gridSize);

        Label spawnCostLabel = new Label("100", skin);
        spawnCostLabel.setStyle(Commons.createLabelStyleWithBackground(spawnCostLabel, skin));
        spawnCostLabel.setFontScale(uiTableElsize*0.015f); // 텍스트 크기 조정
        spawnCostLabel.setColor(Color.GOLD);
	    Table spawnButtonTable = new Table();
	    spawnButtonTable.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))).width(uiTableElsize*0.75f).height(uiTableElsize*0.75f); // 버튼 크기 지정
	    spawnButtonTable.add(spawnCostLabel).pad(5);
	    spawnButtonTable.add(spawnButton).width(uiTableElsize).height(uiTableElsize).pad(5);
	    
        uiTable.add(waveButton).width(uiTableElsize).height(uiTableElsize).right().padRight(15).colspan(3);
        uiTable.row();
        uiTable.add(spawnButtonTable).right().expandY().padRight(15).colspan(3);
        uiTable.row();
        uiTable.add(createCostTable(hrUpgradeCost)).center().width(screenWidth/3);
        uiTable.add(createCostTable(dvUpgradeCost)).center().width(screenWidth/3);
        uiTable.add(createCostTable(slUpgradeCost)).center().width(screenWidth/3);
        uiTable.row();
        uiTable.add(hrUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.add(dvUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.add(slUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.row();
        uiTable.add(lifeStack).width(uiTableElsize).height(uiTableElsize).left().pad(6).expandX();
        uiTable.add(coinStack).width(uiTableElsize).height(uiTableElsize).left().pad(6).expandX().colspan(2);

        float towerInfoElsize = screenWidth * 0.08f; // 버튼 크기 조정


        ImageButton sellButton = Commons.createImageButton("icons/walk_out.png", "icons/money.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (selectedTower != null) {
                    sellTower(selectedTower);
                }
            }
        });
        towerInfoTable = new Table();
        towerInfoTable.setVisible(false);
        towerInfoTable.setPosition(0, (uiTable.getHeight())*0.56f);
        towerInfoTable.setWidth(screenWidth*0.6f);
        towerInfoTable.setHeight((uiTable.getHeight())*0.44f);
        
        Table towerInfoTextTable = new Table();
        Table towerPriceTable = new Table();
        towerInfoTextTable.setWidth(screenWidth*0.3f);
        towerInfoTextTable.setHeight((uiTable.getHeight())*0.44f);
        towerInfoTextTable.setPosition(0, (uiTable.getHeight())*0.56f);
        towerNameLabel = new Label("", skin);
        attackPowerLabel = new Label("", skin);
        towerPriceLabel = new Label("", skin);

        towerNameLabel.setFontScale(towerInfoElsize*0.015f); 
        towerNameLabel.setStyle(Commons.createLabelStyleWithBackground(towerNameLabel, skin));
        towerNameLabel.setColor(Color.DARK_GRAY);
        
        attackPowerLabel.setFontScale(towerInfoElsize*0.015f);
        attackPowerLabel.setStyle(Commons.createLabelStyleWithBackground(attackPowerLabel, skin));
        attackPowerLabel.setColor(Color.DARK_GRAY);
        
        towerPriceLabel.setFontScale(towerInfoElsize*0.013f);
        towerPriceLabel.setStyle(Commons.createLabelStyleWithBackground(towerPriceLabel, skin));
        towerPriceLabel.setColor(Color.DARK_GRAY);

        towerPriceTable.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))).width(uiTableElsize*0.5f).height(uiTableElsize*0.5f); // 버튼 크기 지정
        towerPriceTable.add(towerPriceLabel).pad(5);
        towerPriceTable.add(sellButton).width(towerInfoElsize*0.6f).height(towerInfoElsize*0.6f).pad(5);

        towerInfoTextTable.add(towerNameLabel).expand().pad(2);
        towerInfoTextTable.row();
        towerInfoTextTable.add(attackPowerLabel).expand().pad(2);
        towerInfoTextTable.row();
        towerInfoTextTable.add(towerPriceTable).expand();

        ImageButton upgradeButton = Commons.createImageButton("icons/negociation.png", "icons/negociation_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (selectedTower != null) {
                    upgradeTower(selectedTower);
                }
            }
        });
        

        towerImageTable = new Table();
        towerImageTable.setSize(screenWidth*0.3f, towerInfoTable.getHeight());
        towerImage = new Image();
        towerImage.setSize(screenWidth*0.3f, towerInfoTable.getHeight()*0.66f);
        Table towerUpgradeTable = new Table();
        Label upgradeLabel = new Label("250 30%", skin);
        upgradeLabel.setFontScale(towerInfoElsize*0.015f);
        upgradeLabel.setColor(Color.DARK_GRAY);

        towerUpgradeTable.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))).width(uiTableElsize*0.25f).height(uiTableElsize*0.25f); // 버튼 크기 지정
        towerUpgradeTable.add(upgradeLabel).pad(5);
        towerUpgradeTable.add(upgradeButton).width(towerInfoElsize*0.75f).height(towerInfoElsize*0.75f).pad(5);

        towerImageTable.add(towerImage).colspan(2).expand().pad(2);
        towerImageTable.row();
        towerImageTable.add(towerUpgradeTable);
        
        towerInfoTable.add(towerInfoTextTable).expand();
        towerInfoTable.add(towerImageTable);
        
        // UI 테이블 배경 적용
        TextureRegionDrawable uiTableBackground = new TextureRegionDrawable(new TextureRegion(new Texture(Gdx.files.internal("background/ui_bg.jpg"))));
        uiTableBackground.setMinWidth(uiTable.getWidth());
        uiTableBackground.setMinHeight(uiTable.getHeight());
        uiTable.setBackground(uiTableBackground);

        // 타워 정보 테이블 배경 적용
        TextureRegionDrawable towerInfoTableBackground = new TextureRegionDrawable(new TextureRegion(new Texture(Gdx.files.internal("background/tower_info_bg.jpg"))));
        towerInfoTableBackground.setMinWidth(towerInfoTable.getWidth());
        towerInfoTableBackground.setMinHeight(towerInfoTable.getHeight());
        towerInfoTable.setBackground(towerInfoTableBackground);


        
        if (uiTable.getStage() == null) {
            this.addActor(uiTable);
        }
        if (towerInfoTable.getParent() == null) {
            this.addActor(towerInfoTable);
        }
        initializeSpawnablePositions();
        
        this.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                Actor target = event.getTarget();
                
                // 타워를 클릭했거나, towerInfoTable 내부를 클릭하면 UI 유지
                if (towerInfoTable.isAscendantOf(target) || target instanceof Tower) {
                    return;
                }
                
                // 타워 외부를 클릭하면 UI 닫기
                deselectTower();
            }
        });
        Pixmap originalPixmap = new Pixmap(Gdx.files.internal("icons/focus_off.png"));

        Pixmap resizedPixmap = new Pixmap((int) (gridSize * 0.8), (int) (gridSize * 0.8), originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap,
                                 0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                                 0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());
        focusTexture =  new Texture(resizedPixmap);

        originalPixmap = new Pixmap(Gdx.files.internal("icons/focus.png"));

        resizedPixmap = new Pixmap((int) (gridSize * 0.8), (int) (gridSize * 0.8), originalPixmap.getFormat());
        resizedPixmap.drawPixmap(originalPixmap,
                                 0, 0, originalPixmap.getWidth(), originalPixmap.getHeight(),
                                 0, 0, resizedPixmap.getWidth(), resizedPixmap.getHeight());
        focusTexture2 =  new Texture(resizedPixmap);
        loadAllData();
    }
    
    public void upgradeTower(Tower tower) {
        // 상위 등급 타워로 승급
        if(!tower.upgrade(availableTowers)) {
            // 타워 제거
            towers.removeValue(tower, true);
            towerInfoTable.setVisible(false);
            // 선택된 타워가 팔린 타워라면 선택 해제
            if (selectedTower == tower) {
                deselectTower();
            }
        }
    }

    public void sellTower(Tower tower) {
        // 타워 판매 가격 반환
        currency += tower.getGrade()*30; // 판매 가격 추가
        coinLabel.setText("  " + currency);

        // 타워 제거
        towers.removeValue(tower, true);
        tower.remove();
        // 선택된 타워가 팔린 타워라면 선택 해제
        if (selectedTower == tower) {
            deselectTower();
        }
    }
    

    private Texture circleTexture = new Texture(Gdx.files.internal("icons/circle.png"));
    private boolean isAttackRangeVisible = false; // 사거리 표시 여부

	protected HashMap<String, SkillDto> skillMap;


    // 타워 사거리 표시
    public void showAttackRange(Tower tower) {
        isAttackRangeVisible = true;
        // 사거리 정보 업데이트
        circleTexture.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear);
    }

    // 타워 사거리 숨기기
    public void hideAttackRange() {
        isAttackRangeVisible = false;
    }
 // 타워 선택
    public void selectTower(Tower tower) {
        selectedTower = tower;
        String text = tower.getTeam().equals("hr") ? "인사" : tower.getTeam().equals("dv") ? "개발" : "영업";
        towerNameLabel.setText(tower.getName() + " " + text);

        String attackInfo = String.format("%.1f %.1f %.1f", 
            tower.getPhysicalAttack(), 
            tower.getMagicAttack(), 
            tower.getAttackSpeed()
        );
        attackPowerLabel.setText(attackInfo);
        towerPriceLabel.setText(String.valueOf(tower.getGrade() * 30));

        // 새로운 TextureRegionDrawable을 생성 후 적용
        Texture newTexture = new Texture(Gdx.files.internal(tower.getImagePath()));
        TextureRegionDrawable newDrawable = new TextureRegionDrawable(new TextureRegion(newTexture));
        newDrawable.setMinSize(towerInfoTable.getWidth() * 0.5f, towerInfoTable.getHeight() * 0.66f);
        towerImage.setDrawable(newDrawable);

        // 크기 재조정
        towerImage.setSize(towerInfoTable.getWidth() * 0.5f, towerInfoTable.getHeight() * 0.66f);

        // UI 갱신
        towerInfoTable.setVisible(true);
        towerImageTable.invalidateHierarchy();  // 부모 Table 강제 갱신
        towerImageTable.layout();               // 레이아웃 강제 적용
        showAttackRange(tower);
    }

	 // 타워 선택 해제
	 public void deselectTower() {
	     selectedTower = null;
	     towerInfoTable.setVisible(false); // 선택 해제 시 숨김
	     hideAttackRange();
	 }
	
	 // 타워 클릭 시 선택/해제
	 public void onTowerClicked(Tower tower) {
	     if (selectedTower != tower) {
	         selectTower(tower);
	     } else {
	         deselectTower();
	     }
	 }
	 
	 private void loadUserTowers() {
		    FirebaseTowerService.loadUserData(new FirebaseCallback<UserDto>() {
		        @Override
		        public void onSuccess(UserDto user) {
		            if (user.getUserTowers() != null) {
		                FirebaseTowerService.loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
		                    @Override
		                    public void onSuccess(List<TowerDto> allTowers) {
		                        availableTowers.clear();
		                        for (TowerOwnershipDto ownership : user.getUserTowers().values()) {
		                            for (TowerDto towerDto : allTowers) {
		                                if (ownership.getTowerId().equals(towerDto.getTowerId())) {
		                                    SkillDto skillDto = skillMap.get(towerDto.getTowerId());
		                                    Tower tower = new Tower(towerDto, ownership.getTowerLevel(), gridSize, stage, skillDto);
		                                    availableTowers.add(tower);
		                                    break;
		                                }
		                            }
		                        }
		                    }

		                    @Override
		                    public void onFailure(Exception e) {
		                        Gdx.app.error("StageParent", "타워 데이터를 불러오는 중 오류 발생", e);
		                    }
		                });
		            }
		        }

		        @Override
		        public void onFailure(Exception e) {
		            Gdx.app.error("StageParent", "사용자 데이터를 불러오는 중 오류 발생", e);
		        }
		    });
		}
	 
	 private void loadAllData() {
		    CountDownLatch latch = new CountDownLatch(1); // 1개의 작업이 완료될 때까지 대기
		    loadTowerSkills(latch);

		    new Thread(() -> {
		        try {
		            latch.await(); // 스킬 데이터가 모두 로드될 때까지 대기

		            // 🔹 skillMap이 완전히 채워질 때까지 대기
		            while (skillMap == null || skillMap.isEmpty()) {
		                Thread.sleep(10); // 10ms 단위로 대기하면서 확인
		            }

		            Gdx.app.postRunnable(() -> loadUserTowers()); // 스킬 로드 완료 후 타워 데이터 로드
		        } catch (InterruptedException e) {
		            Gdx.app.error("StageParent", "데이터 로딩 중 인터럽트 발생", e);
		        }
		    }).start();
		}

		private void loadTowerSkills(CountDownLatch latch) {
		    skillMap = new HashMap<>();
		    FirebaseTowerService.loadAllSkills(new FirebaseCallback<List<SkillDto>>() {
		        @Override
		        public void onSuccess(List<SkillDto> allSkills) {
		            skillMap.clear();
		            for (SkillDto skillDto : allSkills) {
		                skillMap.put(skillDto.getSkillId(), skillDto);
		            }
		            latch.countDown(); // 스킬 데이터 로드 완료 후 카운트 다운
		        }

		        @Override
		        public void onFailure(Exception e) {
		            Gdx.app.error("StageParent", "스킬 데이터를 불러오는 중 오류 발생", e);
		            latch.countDown(); // 오류 발생해도 카운트 다운하여 무한 대기 방지
		        }
		    });
		}

	 public void render(SpriteBatch batch, ShapeRenderer shapeRenderer) {
        batch.begin();
        // 배경
        float backgroundHeight = mapHeight * gridSize;
        batch.draw(backgroundTexture, 0, offsetY, Gdx.graphics.getWidth(), backgroundHeight);

        // 경로 및 장애물
        for (Obstacle obstacle : obstacles) {
            obstacle.render(batch);
        }
        for (Enemy enemy : activeEnemies) {
            enemy.render(batch);
        }

        for (Tower tower : towers) {
            tower.render(batch, focusTexture, focusTexture2);
        }
        batch.end();
    	
        if (isAttackRangeVisible && selectedTower != null) {
            float attackRange = selectedTower.getAttackRange();

            circleTexture.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear);
            
            // 원의 크기를 조정해서 attackRange와 일치하도록 설정
            Circle circle = new Circle(selectedTower.getX() + selectedTower.getWidth() / 2, 
                                       selectedTower.getY() + selectedTower.getHeight() / 2, 
                                       attackRange);
            
            shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
            shapeRenderer.setColor(Color.NAVY);
            shapeRenderer.circle(circle.x, circle.y, circle.radius);
            shapeRenderer.setProjectionMatrix(batch.getProjectionMatrix());
            shapeRenderer.end();
        }
        for (Enemy enemy : activeEnemies) {
            shapeRenderer.begin(ShapeRenderer.ShapeType.Filled);
            enemy.renderHealthBar(shapeRenderer);
            shapeRenderer.setProjectionMatrix(batch.getProjectionMatrix());
            shapeRenderer.end();
        }
        batch.setColor(1, 1, 1, 1);

        act(Gdx.graphics.getDeltaTime());
        draw();
    }
    public int getLife() {
    	return life;
    }

    // 장애물 추가 메서드
    public void addObstacle(Obstacle obstacle) {
        if (obstacles == null) {
            obstacles = new Array<>(); 
        }
        obstacles.add(obstacle);
    }
    

    // 게임 종료 처리
    public void dispose() {
        super.dispose();
        if (towers != null) {
            for (Tower tower : towers) {
                tower.dispose();
            }
        }
        if (activeEnemies != null) {
            for (Enemy enemy : activeEnemies) {
            	enemy.dispose();
            }
        }
        if (obstacles != null) {
            for (Obstacle obstacle : obstacles) {
                obstacle.dispose();
            }
        }
        
        backgroundTexture.dispose();
        focusTexture.dispose();
    }
}

