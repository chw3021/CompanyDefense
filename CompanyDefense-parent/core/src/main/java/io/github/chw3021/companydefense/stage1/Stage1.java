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
import io.github.chw3021.companydefense.stage.Stage;
import io.github.chw3021.companydefense.tower.Tower;

import com.badlogic.gdx.InputAdapter;
public class Stage1 extends Stage {
    private float[][] map; // 맵 데이터 (0: 빈 공간, 1: 경로, 2: 장애물)
    private final int mapWidth = 10;
    private final int mapHeight = 5;
    private final int gridSize = 64; // 그리드 크기
    private Texture obstacleTexture;
    private Texture pathTexture;
    private Texture backgroundTexture;

    public Stage1() {
        super();
        initialize();
    }

    @Override
    public void initialize() {
        // 맵 데이터 초기화 (옆으로 누운 S자 경로)
        map = new float[][] {
            { 2, 2, 1, 1, 1, 2, 2, 2, 2, 2 },
            { 2, 2, 1, 2, 1, 2, 2, 2, 2, 2 },
            { 1, 1, 1, 2, 1, 1, 1, 2, 2, 2 },
            { 2, 2, 2, 2, 1, 2, 1, 1, 1, 2 },
            { 2, 2, 2, 2, 1, 1, 1, 2, 2, 2 }
        };
        //<a href="https://kr.freepik.com/free-vector/realistic-office-design-flat-lay_24007772.htm">작가 pikisuperstar 출처 Freepik</a>
        // 텍스처 로드
        Pixmap obstaclePixmap = new Pixmap(Gdx.files.internal("constructure/obstacle/obstacle.jpg"));
        Pixmap pathPixmap = new Pixmap(Gdx.files.internal("constructure/path/path.png"));
        backgroundTexture = new Texture(Gdx.files.internal("background/stage1.jpg"));

        // 장애물 추가
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                if (map[y][x] == 2) {
                    // 장애물 생성
                    addObstacle(new Obstacle(x * gridSize, y * gridSize, obstaclePixmap, gridSize, gridSize));
                } else if (map[y][x] == 1) {
                    // 경로를 시각적으로 표현하기 위해 텍스처를 배치
                    pathVisuals.add(new Obstacle(x * gridSize, y * gridSize, pathPixmap, gridSize, gridSize));
                }
            }
        }

        // A* 경로 설정
        setupAStar();

        // 적 웨이브 설정
        Array<Enemy> waveEnemies = new Array<>();
        waveEnemies.add(new Enemy(0, 2 * gridSize, 100, 5, 5, 100, "normal", "enemy/printer.png", new Vector2(9 * gridSize, 2 * gridSize)));
        setupWave(waveEnemies);
    }

    @Override
    public void render(SpriteBatch batch) {
        // 배경 렌더링 (가장 맨 뒤로)
        batch.begin();
        batch.draw(backgroundTexture, 0, 0, Gdx.graphics.getWidth(), Gdx.graphics.getHeight());  // 배경을 화면 크기대로 그리기
        batch.end();

        // 부모 클래스의 렌더링 (UI 및 버튼 등)
        super.render(batch);
    }
    @Override
    public boolean canSpawnTowerAt(float x, float y) {
        int gridX = (int) (x / gridSize);
        int gridY = (int) (y / gridSize);

        // 범위를 벗어나거나 경로에 위치한 경우 배치 불가
        if (gridX < 0 || gridX >= mapWidth || gridY < 0 || gridY >= mapHeight) {
            return false;
        }
        return map[gridY][gridX] == 2; // 장애물 위치에만 배치 가능
    }

    @Override
    public void dispose() {
        super.dispose();
        obstacleTexture.dispose();
        pathTexture.dispose();
        backgroundTexture.dispose();
    }
}
