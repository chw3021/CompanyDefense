package io.github.chw3021.companydefense.stage;

import java.util.HashMap;
import java.util.List;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
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
import com.badlogic.gdx.scenes.scene2d.ui.Label.LabelStyle;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Stack;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.utils.BaseDrawable;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.Drawable;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Align;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class StageParent extends Stage{
	protected Game game;
    
	protected float[][] map; // 맵 데이터 (0: 장애물)
    protected WaveManager waveManager;
    protected Array<Enemy> activeEnemies;
    public Array<Tower> towers;
    protected float waveTimeInterval = 5.0f;  // 웨이브가 시작되는 시간 간격
    protected float timeSinceLastWave = 0.0f; // 마지막 웨이브 이후 경과 시간
    
    protected Array<Obstacle> obstacles;  // 장애물 목록
    protected Array<Obstacle> pathVisuals;
    protected float offsetY = 0;
    protected AStarPathfinding aStar;  // AStar 경로 탐색
    protected int life = 1;  // 초기 Life 설정

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
    private Table towerInfoTable;
    private Label towerNameLabel, attackPowerLabel, towerPriceLabel, hrLabel, dvLabel, slLabel;
    private Label hrUpgradeCost,dvUpgradeCost,slUpgradeCost;
    private Tower selectedTower = null;
    private StageParent stage = this;
    
    private HashMap<String, Integer> teamLevel = new HashMap<String, Integer>();

	private float uiTableElsize;

	private SpriteBatch batch2;
    
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
            this.addActor(towerToSpawn);
            towers.add(towerToSpawn);
            currency -= 100;

        } else {
            System.out.println("No valid positions to spawn a tower!");
        }
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
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        towers = new Array<>();
        batch2 = new SpriteBatch();

        activeEnemies = new Array<>();
        waveManager = new WaveManager(this, game);
        availableTowers = new Array<>();
        
    }
    
    @Override
    public void act(float delta) {
    	this.setDebugAll(true);
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
        lifeLabel.setText("     " + life);
        coinLabel.setText("     " + currency);

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
    
    public ImageButton createImageButton(String upImagePath, String downImagePath, ClickListener listener) {
        // 텍스처 로드
        Texture upTexture = new Texture(Gdx.files.internal(upImagePath));
        Texture downTexture = new Texture(Gdx.files.internal(downImagePath));

        // TextureRegionDrawable로 버튼 이미지 설정
        TextureRegionDrawable upDrawable = new TextureRegionDrawable(new TextureRegion(upTexture));
        TextureRegionDrawable downDrawable = new TextureRegionDrawable(new TextureRegion(downTexture));

        // ImageButtonStyle 설정
        ImageButton.ImageButtonStyle style = new ImageButton.ImageButtonStyle();
        style.up = upDrawable;
        style.down = downDrawable;


        // ImageButton 생성
        ImageButton button = new ImageButton(style);
        button.addListener(listener); // 클릭 리스너 추가

        return button;
    }
    private LabelStyle createLabelStyleWithBackground(Label label) {
        LabelStyle labelStyle = new LabelStyle();
        labelStyle.font = skin.getFont("default");
        labelStyle.fontColor = Color.WHITE;
        labelStyle.background = createBackground(label);
        return labelStyle;
    }

	private Drawable createBackground(Label label) {
	    Pixmap labelColor = new Pixmap(1, 1, Pixmap.Format.RGBA8888);
	    Color color = new Color(Color.LIGHT_GRAY);
	    color.a = 0.35f;
	    labelColor.setColor(color);
	    labelColor.fill();
	
	    Texture texture = new Texture(labelColor);
	
	    return new BaseDrawable() {
	
	        @Override
	        public void draw(Batch batch, float x, float y, float width, float height) {
	            GlyphLayout layout = label.getGlyphLayout();
	            x = label.getX();
	            y = label.getY();
	            batch.draw(texture, x, y, layout.width, layout.height);
	        }
	    };
	}
	private Table createUpgradeButton(String labelText, String iconUp, String iconDown, String teamName) {
	    ImageButton button = createImageButton(iconUp, iconDown, new ClickListener() {
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

	    label.setStyle(createLabelStyleWithBackground(label));
	    label.setAlignment(Align.left); // 왼쪽 정렬
	    label.setFontScale(uiTableElsize*0.015f); // 텍스트 크기 조정

	    // Table을 사용하여 Label과 Button을 나란히 배치
	    Table table = new Table();
	    table.add(label).left().expand().padLeft(1);  // 라벨을 왼쪽에 배치, 오른쪽 여백 추가
	    table.add(button).width(uiTableElsize).height(uiTableElsize).right().padRight(5); // 버튼 크기 지정

	    return table;
	}

    private void upgradeTeamTowers(String teamName) {
        int cost = 50*teamLevel.computeIfPresent(teamName, (k,v) -> v=v+1); // 업그레이드 비용 (원하는 값으로 설정)
	     if (teamName.equals("hr")) hrUpgradeCost.setText(cost);
	     if (teamName.equals("dv")) dvUpgradeCost.setText(cost);
	     if (teamName.equals("sl")) slUpgradeCost.setText(cost);
        
        if (currency < cost) {
            System.out.println("재화 부족!");
            return;
        }

        currency -= cost; // 재화 차감

        for (Tower tower : towers) {
            if (tower.getTeam().equals(teamName)) {
                tower.setPhysicalAttack(tower.getPhysicalAttack() * 1.05f);
                tower.setMagicAttack(tower.getMagicAttack() * 1.05f);
            }
        }

        updateUpgradeLabel(teamName);
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
    

	 
    public void initialize() {

        ImageButton waveButton = createImageButton("icons/start-button.png", "icons/start-button_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                waveManager.startNextWave();
            }
        });

        ImageButton spawnButton = createImageButton("icons/work.png", "icons/work_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                spawnTower();
            }
        });

        float screenWidth = Gdx.graphics.getWidth();
        float screenHeight = Gdx.graphics.getHeight();
        uiTableElsize = screenWidth * 0.1f; // 버튼 크기 축소
        
        coinLabel = new Label(null, skin);
        coinLabel.setStyle(createLabelStyleWithBackground(coinLabel));
        coinLabel.setFontScale(uiTableElsize*0.02f); // 폰트 크기 축소

		// 버튼 생성
		Table hrUpgrade = createUpgradeButton("인사", "icons/hrup.png", "icons/hrup_down.png", "hr");
		Table dvUpgrade = createUpgradeButton("개발", "icons/dvup.png", "icons/dvup_down.png", "dv");
		Table slUpgrade = createUpgradeButton("영업", "icons/slup.png", "icons/slup_down.png", "sl");

        Stack coinStack = new Stack();
        coinStack.add(new Image(new Texture(Gdx.files.internal("icons/coin.png"))));
        coinStack.add(coinLabel);

        Stack lifeStack = new Stack();
        // Life Label과 하트 이미지 생성
        Texture heartTexture = new Texture(Gdx.files.internal("icons/heart.png"));
        Image heartImage = new Image(heartTexture);
        lifeLabel = new Label(null, skin);
        lifeLabel.setStyle(createLabelStyleWithBackground(lifeLabel));
        lifeLabel.setFontScale(uiTableElsize*0.02f); // 텍스트 크기 조정
        lifeStack.add(heartImage);
        lifeStack.add(lifeLabel);
        
        uiTable = new Table();
        uiTable.setWidth(screenWidth);
        uiTable.setHeight(screenHeight-mapHeight*gridSize);

        uiTable.add(waveButton).width(uiTableElsize).height(uiTableElsize).right().padRight(15).colspan(3);
        uiTable.row();
        uiTable.add(spawnButton).width(uiTableElsize).height(uiTableElsize).right().expandY().padRight(15).colspan(3);
        uiTable.row();
        uiTable.add(hrUpgradeCost).center().width(screenWidth/3);
        uiTable.add(dvUpgradeCost).center().width(screenWidth/3);
        uiTable.add(slUpgradeCost).center().width(screenWidth/3);
        uiTable.row();
        uiTable.add(hrUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.add(dvUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.add(slUpgrade).center().width(screenWidth/3).pad(1);
        uiTable.row();
        uiTable.add(lifeStack).width(uiTableElsize).height(uiTableElsize).left().pad(6).expandX();
        uiTable.add(coinStack).width(uiTableElsize).height(uiTableElsize).left().pad(6).expandX().colspan(2);

        float towerInfoElsize = screenWidth * 0.08f; // 버튼 크기 조정
        
        towerInfoTable = new Table();
        towerInfoTable.setVisible(false);
        towerInfoTable.setPosition(0, (uiTable.getHeight())*0.56f);
        towerInfoTable.setWidth(screenWidth*0.6f);
        towerInfoTable.setHeight((uiTable.getHeight())*0.44f);

        towerNameLabel = new Label("", skin);
        attackPowerLabel = new Label("", skin);
        towerPriceLabel = new Label("", skin);

        towerNameLabel.setFontScale(towerInfoElsize*0.02f); 
        towerNameLabel.setStyle(createLabelStyleWithBackground(towerNameLabel));
        
        attackPowerLabel.setFontScale(towerInfoElsize*0.02f);
        attackPowerLabel.setStyle(createLabelStyleWithBackground(attackPowerLabel));
        
        towerPriceLabel.setFontScale(towerInfoElsize*0.02f);
        towerPriceLabel.setStyle(createLabelStyleWithBackground(towerPriceLabel));
        

        towerInfoTable.add(towerNameLabel).colspan(2).expand().pad(2);
        towerInfoTable.row();
        towerInfoTable.add(attackPowerLabel).colspan(2).expand().pad(2);
        towerInfoTable.row();
        towerInfoTable.add(towerPriceLabel).colspan(2).expand().pad(2);

        ImageButton upgradeButton = createImageButton("icons/negociation.png", "icons/negociation_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (selectedTower != null) {
                    upgradeTower(selectedTower);
                }
            }
        });

        ImageButton sellButton = createImageButton("icons/walk_out.png", "icons/money.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                if (selectedTower != null) {
                    sellTower(selectedTower);
                }
            }
        });
        
        towerInfoTable.add(upgradeButton).width(towerInfoElsize).height(towerInfoElsize);
        towerInfoTable.add(sellButton).width(towerInfoElsize).height(towerInfoElsize);
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
        loadUserTowers();
    }
    
    public void upgradeTower(Tower tower) {
        // 상위 등급 타워로 승급
        if(!tower.upgrade(availableTowers)) {
            // 타워 제거
            towers.removeValue(tower, true);
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
	     towerNameLabel.setText(tower.getName());
	     attackPowerLabel.setText(tower.getPhysicalAttack()+" / " + tower.getMagicAttack() 
	     +" / "+tower.getAttackSpeed());
	     towerPriceLabel.setText("Sell Price: " + (tower.getGrade() * 30));
	
	     towerInfoTable.setVisible(true); // 선택 시 표시
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
                                        Tower tower = new Tower(towerDto, ownership.getTowerLevel(), gridSize, stage);
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
    
    public void render(SpriteBatch batch, ShapeRenderer shapeRenderer) {

    	batch.begin();
        // 배경
        float backgroundHeight = mapHeight * gridSize;
        batch.draw(backgroundTexture, 0, offsetY, Gdx.graphics.getWidth(), backgroundHeight);

        // 경로 및 장애물
        for (Obstacle path : pathVisuals) {
            path.render(batch);
        }
        for (Obstacle obstacle : obstacles) {
            obstacle.render(batch);
        }
        // 타워 및 적
        for (Tower tower : towers) {
            tower.render(batch);
        }
        for (Enemy enemy : activeEnemies) {
            enemy.render(batch);
        }
        batch2.begin();
        for (Tower tower : towers) {
            tower.renderGuide(batch2, focusTexture, focusTexture2);
        }
        batch2.end();
        if (isAttackRangeVisible && selectedTower != null) {
            float attackRange = selectedTower.getAttackRange();
            float diameter = attackRange * 2; // 원의 크기 = 직경

            circleTexture.setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear);
            
            // 원의 크기를 조정해서 attackRange와 일치하도록 설정
            Circle circle = new Circle(selectedTower.getX() + selectedTower.getWidth() / 2, 
                                       selectedTower.getY() + selectedTower.getHeight() / 2, 
                                       attackRange);
            
            shapeRenderer.begin(ShapeRenderer.ShapeType.Line);
            shapeRenderer.setColor(Color.NAVY);
            shapeRenderer.circle(circle.x, circle.y, circle.radius);
            shapeRenderer.end();
        }
    	batch.end();
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

