package io.github.chw3021.companydefense.stage1;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.enemy.Enemy;
import io.github.chw3021.companydefense.obstacle.Obstacle;
import io.github.chw3021.companydefense.stage.StageParent;
import io.github.chw3021.companydefense.stage.Wave;
import io.github.chw3021.companydefense.tower.Tower;

import com.badlogic.gdx.InputAdapter;
public class Stage1 extends StageParent {
    private Texture obstacleTexture;
    private Texture pathTexture;
    private Texture backgroundTexture;

    public Stage1() {
        super();
        initialize();
    }

	private Wave createFirstWave() {
	    Wave wave = new Wave(2.0f);
        for(int i = 0; i<20; i++) {
        	Enemy printer = generateEnemy(100, 1, 1, 10, "normal", "enemy/printer.png");
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
		return new Enemy(0, offsetY,  // start position
			health, physicalDefense, magicDefense,        // health, physical/magic defense 
			moveSpeed,              // move speed
			type,         // type
			path, 
			new Vector2((mapWidth) * gridSize, (mapHeight) * gridSize),
			mapWidth,
			mapHeight,
			gridSize
	    );
	}

    @Override
    public void initialize() {
        // 맵 데이터 초기화 (옆으로 누운 S자 경로)
    	map = new float[][] {
    	    { 1, 1, 1, 1, 1, 1, 1 },
    	    { 2, 2, 2, 2, 2, 2 ,1 },
    	    { 1, 1, 1, 1, 1, 1, 1 },
    	    { 1, 2, 2, 2, 2, 2, 2 },
    	    { 1, 1, 1, 1, 1, 1, 1 },
    	    { 2, 2, 2, 2, 2, 2, 1 },
    	    { 1, 1, 1, 1, 1, 1, 1 }
    	};
        mapWidth = 7;  // 예시: 맵의 가로 크기
        mapHeight = 7; // 예시: 맵의 세로 크기
        gridSize = Gdx.graphics.getWidth() / mapWidth; // 화면 너비에 맞게 그리드 크기 설정

        // 배경 텍스처 로드
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.jpg"));

        //<a href="https://kr.freepik.com/free-vector/realistic-office-design-flat-lay_24007772.htm">작가 pikisuperstar 출처 Freepik</a>
        // 텍스처 로드
        Pixmap obstaclePixmap = new Pixmap(Gdx.files.internal("constructure/obstacle/obstacle.jpg"));
        //Pixmap pathPixmap = new Pixmap(Gdx.files.internal("constructure/path/path.png"));
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.jpg"));
        offsetY = Gdx.graphics.getHeight() - (mapHeight * gridSize);
        // 장애물 추가
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                float adjustedY = offsetY + y * gridSize;
                if (map[y][x] == 2) {
                    // 장애물 생성
                    addObstacle(new Obstacle(x * gridSize, adjustedY, obstaclePixmap, gridSize, gridSize));
                }
                
            }
        }
        // A* 경로 설정
    	setupAStar();

        availableTowers = new Array<>();
        availableTowers.add(new Tower(0, 0, 100, 100, 1, 2, "tower/class1/man1.png", "man", "closest"));

        Wave wave1 = createFirstWave();
        Wave wave2 = createSecondWave();
        for(int i = 0; i<20; i++) {
        	Enemy printer = generateEnemy(100, 1, 1, 10, "normal", "enemy/printer.png");
        	wave2.addEnemy(printer);
        	printer.setWave(wave2);
        }
        
        waveManager.addWave(wave1);
        waveManager.addWave(wave2);
        
    	super.initialize();
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

        act(Gdx.graphics.getDeltaTime());
        super.render(batch);
        
    }
    @Override
    public void dispose() {
        super.dispose();
        obstacleTexture.dispose();
        pathTexture.dispose();
        backgroundTexture.dispose();
    }
}
