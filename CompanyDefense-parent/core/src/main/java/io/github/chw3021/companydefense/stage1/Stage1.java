package io.github.chw3021.companydefense.stage1;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.pathfinding.AStarPathfinding;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.stage.Wave;
import io.github.chw3021.companydefense.tower.Tower;
public class Stage1 extends StageParent {
    private float startX;
    private float startY;
    private float endX;
    private float endY;
    
    public Stage1(Game game) {
        super();
        super.game = game;
        initialize();
    }

	private Wave createFirstWave() {
	    Wave wave = new Wave(2.0f);
        for(int i = 0; i<1; i++) {
        	Enemy printer = generateEnemy(100, 1, 1, 1000, "normal", "enemy/printer.png");
        	wave.addEnemy(printer);
        	printer.setWave(wave);
        }
	    return wave;
	}
	
	private Wave createSecondWave() {
	    Array<Enemy> enemiesForWave = new Array<>();
	    return new Wave(enemiesForWave, 1.5f);
	}
	
	private Enemy generateEnemy(float health, float physicalDefense, 
			float magicDefense, float moveSpeed, String type, String path) {
		return new Enemy(startX* gridSize, startY* gridSize+offsetY,  // start position
			health, physicalDefense, magicDefense,        // health, physical/magic defense 
			moveSpeed,              // move speed
			type,         // type
			path, 
			new Vector2(endX * gridSize, (endY * gridSize)+offsetY),
			this,
			map
	    );
	}
    @Override
    public void initialize() {
    	super.initialize();
    	map = new float[][] {
    	    { 2.0f, 1.0f, 1.0f, 2.1f, 0.0f, 0.0f, 1.6f, 1.0f, 1.0f, 1.7f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.9f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.8f },
    	    { 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f },
    	    { 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f },
    	    { 1.2f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.3f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f },
    	    { 1.1f, 0.0f, 0.0f, 2.2f, 0.0f, 0.0f, 1.5f, 1.0f, 1.0f, 1.4f },
    	};

        mapWidth = 10;  // 예시: 맵의 가로 크기
        mapHeight = 10; // 예시: 맵의 세로 크기
        gridSize = Gdx.graphics.getWidth() / mapWidth; // 화면 너비에 맞게 그리드 크기 설정

        // 배경 텍스처 로드
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.jpg"));

        //<a href="https://kr.freepik.com/free-vector/realistic-office-design-flat-lay_24007772.htm">작가 pikisuperstar 출처 Freepik</a>
        // 텍스처 로드
        Pixmap obstaclePixmap = new Pixmap(Gdx.files.internal("constructure/obstacle/obstacle.jpg"));
        //Pixmap pathPixmap = new Pixmap(Gdx.files.internal("constructure/path/path.png"));
        offsetY = Gdx.graphics.getHeight() - (mapHeight * gridSize);
        
        aStar = AStarPathfinding.getInstance(mapWidth, mapHeight, gridSize);
        aStar.setObstacles(map);
        
        // 장애물 추가
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                float adjustedY = offsetY + y * gridSize;
                if (map[y][x] == 0.0f) {
                    // 장애물 생성
                    addObstacle(new Obstacle(x * gridSize, adjustedY, obstaclePixmap, gridSize, gridSize));
                }
                if (map[y][x] == 1.1f) {
                	startX = x;
                	startY = y;
                }
                if (map[y][x] == 2.2f) {
                	endX = x;
                	endY = y;
                }
                
            }
        }


        availableTowers = new Array<>();
        availableTowers.add(new Tower(0, 0, 100, 100, 1, gridSize*2, "tower/class1/man1.png", "man", "closest"));

        Wave wave1 = createFirstWave();
        
        waveManager.addWave(wave1);
        
    }

    @Override
    public void render(SpriteBatch batch) {
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
        batch.end();
        super.render(batch);
        
    }
    @Override
    public void dispose() {
        super.dispose();
    }
}
