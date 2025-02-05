package io.github.chw3021.companydefense.stage;

import java.util.List;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.InputMultiplexer;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Stack;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.tower.Tower;

public abstract class StageParent extends Stage{
	protected Game game;
    
	protected float[][] map; // 맵 데이터 (0: 장애물)
    protected WaveManager waveManager;
    protected Array<Enemy> activeEnemies;
    protected Array<Tower> towers;
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
    protected Array<Tower> availableTowers;
    private Array<Vector2> spawnablePositions;

    protected Texture obstacleTexture;
    protected Texture pathTexture;
    protected Texture backgroundTexture;

    private ImageButton spawnButton;
    private Skin skin;
    private Label lifeLabel; // Life를 표시하는 Label
    private ImageButton waveButton; // 웨이브 시작 버튼
    private Table uiTable; // UI 구성
    private Label coinLabel;
    private int currency = 1000; // 초기 재화 값 (필요시 업데이트)
    private Table towerInfoTable;
    private Label towerNameLabel, attackPowerLabel, attackSpeedLabel, towerLevelLabel, towerPriceLabel;

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

        if (filteredPositions.size > 0) {
            Vector2 selectedPosition = filteredPositions.random();

            // 타워 배치
            Tower towerToSpawn = new Tower(availableTowers.random());
            towerToSpawn.setPosition(selectedPosition);
            towers.add(towerToSpawn);

            // 재화 소모
            if(currency-100<0) {
                System.out.println("money!");
            	return;
            }
            currency -= 100; // 예시: 타워 하나당 100 재화 소모
            coinLabel.setText("Coins: " + currency); // UI 업데이트
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
	
    public StageParent() {
        super();
        pathVisuals = new Array<>();
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        towers = new Array<>();

        activeEnemies = new Array<>();
    }
    
    @Override
    public void act(float delta) {
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
        lifeLabel.setText("   " + life);

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

        // 클릭된 상태를 처리하기 위해 checked 상태 추가
        style.over = upDrawable;
        style.focused = downDrawable;
        style.checkedDown = downDrawable;
        style.checked = downDrawable;  // 다운 상태와 클릭된 상태를 동일하게 설정

        // ImageButton 생성
        ImageButton button = new ImageButton(style);
        button.addListener(listener); // 클릭 리스너 추가

        return button;
    }

    
    
    public void initialize() {
        waveManager = new WaveManager(this, game);


        waveButton = createImageButton("icons/start-button.png", "icons/start-button_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
            	waveManager.startNextWave(); // 웨이브 시작
            }
        });
        

        spawnButton = createImageButton("icons/recruitment.png", "icons/recruitment_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                spawnTower();
            }
        });
        
        
        Stack stack = new Stack();
        // Life Label과 하트 이미지 생성
        Texture heartTexture = new Texture(Gdx.files.internal("icons/heart.png"));
        Image heartImage = new Image(heartTexture);
        lifeLabel = new Label(null, skin);
        lifeLabel.setFontScale(1.5f); // 텍스트 크기 조정
        stack.add(heartImage);
        stack.add(lifeLabel);

        // UI 테이블 설정
        uiTable = new Table();
        uiTable.setFillParent(true);
        uiTable.bottom(); // 하단에 배치

        // Start Wave 버튼을 하단 오른쪽에 배치
        uiTable.add().expandX();
        uiTable.add(waveButton).width(60).height(60).pad(10).right(); // Wave 시작 버튼 배치
        
        uiTable.row(); // 새로운 행 추가
        uiTable.add(stack).width(30).height(30).pad(10).left(); // Life 텍스트
        uiTable.add().expandX();
        
        // Spawn Tower 버튼을 하단 왼쪽에 배치
        uiTable.row(); // 새로운 행 추가
        uiTable.add(spawnButton).width(60).height(60).pad(10).colspan(2); // Spawn 버튼 배치

        coinLabel = new Label("Coins: " + currency, skin);
        coinLabel.setFontScale(1.5f);

        Stack coinStack = new Stack();
        coinStack.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))); // 동전 이미지
        coinStack.add(coinLabel);

        uiTable.row();
        uiTable.add(coinStack).width(30).height(30).pad(10).right(); // 재화 표시

        towerInfoTable = new Table();
        towerInfoTable.top().left();
        towerInfoTable.setFillParent(true);
        towerInfoTable.padTop(50); // 화면 상단 여백
        
        towerNameLabel = new Label("Name: ", skin);
        attackPowerLabel = new Label("Attack: ", skin);
        attackSpeedLabel = new Label("Speed: ", skin);
        towerLevelLabel = new Label("Level: ", skin);
        towerPriceLabel = new Label("Price: ", skin);
        
        towerInfoTable.add(towerNameLabel).colspan(2).fillX().padBottom(5);
        towerInfoTable.row();
        towerInfoTable.add(attackPowerLabel).colspan(2).fillX().padBottom(5);
        towerInfoTable.row();
        towerInfoTable.add(attackSpeedLabel).colspan(2).fillX().padBottom(5);
        towerInfoTable.row();
        towerInfoTable.add(towerLevelLabel).colspan(2).fillX().padBottom(5);
        towerInfoTable.row();
        towerInfoTable.add(towerPriceLabel).colspan(2).fillX().padBottom(5);
        
        ImageButton upgradeButton = createImageButton("icons/upgrade.png", "icons/upgrade_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                upgradeTower(selectedTower); // 타워 진급 로직
            }
        });

        ImageButton sellButton = createImageButton("icons/sell.png", "icons/sell_down.png", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                sellTower(selectedTower); // 타워 판매 로직
            }
        });

        
        // UI 테이블을 Stage에 추가
        this.addActor(uiTable);

        availableTowers = new Array<>();
        initializeSpawnablePositions();

        // InputMultiplexer 설정
        InputMultiplexer inputMultiplexer = new InputMultiplexer();
        inputMultiplexer.addProcessor(this); // StageParent 자체를 InputProcessor로 설정
        Gdx.input.setInputProcessor(inputMultiplexer);
        
        loadUserTowers();
    }
    public void upgradeTower(Tower tower) {
        // 상위 등급 타워로 승급
        tower.upgrade(); // upgrade() 메서드를 Tower 클래스에 구현
    }

    public void sellTower(Tower tower) {
        // 타워 판매 가격 반환
        currency += tower.getSellPrice(); // 판매 가격 추가
        coinLabel.setText("Coins: " + currency);

        // 타워 제거
        towers.removeValue(tower, true);
        tower.dispose(); // 타워 리소스 해제
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
                                        Tower tower = new Tower(towerDto, ownership.getTowerLevel(), gridSize);
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
    
    public void render(SpriteBatch batch) {
        for (Tower tower : towers) {
            float attackRange = tower.getAttackRange();
            batch.setColor(1, 0, 0, 0.3f); // 반투명 빨간색
            batch.draw(circleTexture, tower.getPosition().x - attackRange, tower.getPosition().y - attackRange,
                        attackRange * 2, attackRange * 2);
        }
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
    }
}

