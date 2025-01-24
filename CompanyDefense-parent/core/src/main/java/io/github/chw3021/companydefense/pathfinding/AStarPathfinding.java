package io.github.chw3021.companydefense.pathfinding;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.math.Vector2;

import java.util.*;


public class AStarPathfinding {
    private int mapWidth, mapHeight, gridSize, offsetY;
    private boolean[][] obstacles;

    public AStarPathfinding(int mapWidth, int mapHeight, int gridSize) {
        this.mapWidth = mapWidth;
        this.mapHeight = mapHeight;
        this.gridSize = gridSize;
        this.obstacles = new boolean[mapWidth][mapHeight];
        offsetY = Gdx.graphics.getHeight() - (mapHeight * gridSize);
    }

    private static AStarPathfinding instance;
    public static AStarPathfinding getInstance(int mapWidth, int mapHeight, int gridSize) {
        if (instance == null) {
            instance = new AStarPathfinding(mapWidth, mapHeight, gridSize);
        }
        return instance;
    }
    // 장애물 추가 메서드
    public void addObstacle(int x, int y) {
        if (isValidGrid(x, y)) {
            obstacles[x][y] = true;
            
        }
    }
    // 장애물을 Stage에서 설정하도록 하는 메서드
    public void setObstacles(float[][] map) {
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                if (map[y][x] == 2) { // 장애물 값이 2인 경우
                    addObstacle(x, y);
                }
            }
        }
    }

    public List<Vector2> findPath(float[][] map) {
        List<Vector2> path = new ArrayList<>();
        float startValue = 1.1f;
        path.clear();  // 이전 경로 초기화
        int mapHeight = map.length;
        int mapWidth = map[0].length;

        // 시작 위치 찾기
        int currentX = -1, currentY = -1;
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                if (map[y][x] == startValue) {
                    currentX = x;
                    currentY = y;
                    break;
                }
            }
            if (currentX != -1) break;
        }

        if (currentX == -1 || currentY == -1) {
            return path;
        }

        path.add(new Vector2(currentX*gridSize, currentY*gridSize + offsetY));

        // 경로 찾기
        float currentValue = startValue;
        while (true) {
            currentValue += 0.1f;  // 다음 값을 탐색
            boolean foundNext = false;

            for (int y = 0; y < mapHeight; y++) {
                for (int x = 0; x < mapWidth; x++) {
                    if (Math.abs(map[y][x] - currentValue) < 0.0001f) {
                        currentX = x;
                        currentY = y;
                        path.add(new Vector2(currentX*gridSize, currentY*gridSize + offsetY));
                        foundNext = true;
                        break;
                    }
                }
                if (foundNext) break;
            }

            if (!foundNext) {
                break;
            }
        }
        return path;
    }

    private boolean isValidGrid(int x, int y) {
        return x >= 0 && y >= 0 && x < mapWidth && y < mapHeight;
    }

}