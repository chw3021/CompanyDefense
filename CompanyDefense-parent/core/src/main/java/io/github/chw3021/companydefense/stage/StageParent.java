package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.InputMultiplexer;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Stack;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;
import io.github.chw3021.companydefense.enemy.Enemy;
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
    private TextButton waveButton; // 웨이브 시작 버튼
    private Table uiTable; // UI 구성
    
    
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

        // 필터링
        for (Vector2 position : spawnablePositions) {
            if (canSpawnTowerAt(position.x, position.y)) {
                filteredPositions.add(position);
            }
        }

        if (filteredPositions.size > 0) {
            // 랜덤하게 위치 선택
            Vector2 selectedPosition = filteredPositions.random();

            // 타워 배치
            Tower towerToSpawn = new Tower(availableTowers.random());
            towerToSpawn.setPosition(selectedPosition);
            towers.add(towerToSpawn);
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
    
    public void initialize() {
        waveManager = new WaveManager(this, game);

        // 웨이브 시작 버튼 생성
        waveButton = new TextButton("Start Wave", skin);
        waveButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                waveManager.startNextWave(); // 웨이브 시작
                waveButton.setDisabled(true); // 버튼 비활성화
            }
        });

        // Spawn Tower 버튼 생성
        spawnButton = new ImageButton(skin);
        spawnButton.addListener(new ClickListener() {
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
        uiTable.add(waveButton).width(200).height(60).pad(10).right(); // Wave 시작 버튼 배치
        
        uiTable.row(); // 새로운 행 추가
        uiTable.add(stack).width(30).height(30).pad(10).left(); // Life 텍스트
        uiTable.add().expandX();
        
        // Spawn Tower 버튼을 하단 왼쪽에 배치
        uiTable.row(); // 새로운 행 추가
        uiTable.add(spawnButton).width(200).height(60).pad(10); // Spawn 버튼 배치

        // UI 테이블을 Stage에 추가
        this.addActor(uiTable);

        initializeSpawnablePositions();

        // InputMultiplexer 설정
        InputMultiplexer inputMultiplexer = new InputMultiplexer();
        inputMultiplexer.addProcessor(this); // StageParent 자체를 InputProcessor로 설정
        Gdx.input.setInputProcessor(inputMultiplexer);
    }

    public void render(SpriteBatch batch) {
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

