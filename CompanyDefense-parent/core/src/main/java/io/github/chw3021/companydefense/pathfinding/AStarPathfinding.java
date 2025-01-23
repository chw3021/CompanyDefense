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
            System.out.println("Obstacle added at: x=" + x + ", y=" + y);
            System.out.println(obstacles[x][y]);
            
        } else {
            System.out.println("Invalid obstacle coordinates: x=" + x + ", y=" + y);
        }
    }
    // 장애물을 Stage에서 설정하도록 하는 메서드
    public void setObstacles(float[][] map) {
        for (int y = 0; y < mapHeight; y++) {
            for (int x = 0; x < mapWidth; x++) {
                if (map[y][x] == 2) { // 장애물 값이 2인 경우
                    addObstacle(x, y);
                    System.out.println("obs " + x + " " + y); // 디버그 출력
                }
            }
        }
    }

    public List<Vector2> findPath(int startXR, int startYR, int targetXR, int targetYR) {
        PriorityQueue<Node> openList = new PriorityQueue<>(Comparator.comparingDouble(n -> n.f));
        Set<Node> closedList = new HashSet<>();
        int startX = startXR / gridSize;
        int startY = (startYR - offsetY) / gridSize;
        int targetX = targetXR / gridSize -1;
        int targetY = (targetYR - offsetY) / gridSize -1;
        
        Node startNode = new Node(startX, startY, null, 0, heuristic(startX, startY, targetX, targetY));
        openList.add(startNode);

        while (!openList.isEmpty()) {
            Node current = openList.poll();

            // 목표 지점 도달
            if (current.x == targetX && current.y == targetY) {
                return reconstructPath(current);
            }

            closedList.add(current);
            // 인접 노드 탐색
            for (int[] dir : new int[][]{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
                int newX = current.x + dir[0];
                int newY = current.y + dir[1];
                
                if (isValidGrid(newX, newY) && !obstacles[newX][newY]) {
                    System.out.println(targetX + " "+ targetY);
                    System.out.println(newX + " "+ newY);
                    Node neighbor = new Node(newX, newY, current,
                            current.g + 1, heuristic(newX, newY, targetX, targetY));
                    
                    if (closedList.contains(neighbor)) continue;

                    if (!openList.contains(neighbor) || neighbor.g < current.g) {
                        openList.add(neighbor);
                    }
                }
            }
        }

        return Collections.emptyList(); // 경로를 찾지 못한 경우
    }

    private boolean isValidGrid(int x, int y) {
        return x >= 0 && y >= 0 && x < mapWidth && y < mapHeight;
    }

    private double heuristic(int x1, int y1, int x2, int y2) {
        return Math.abs(x1 - x2) + Math.abs(y1 - y2); // 맨해튼 거리
    }

    private List<Vector2> reconstructPath(Node targetNode) {
        List<Vector2> path = new ArrayList<>();
        Node current = targetNode;

        while (current != null) {
            // offsetY를 y 좌표에 다시 더해 원래 좌표로 변환
            path.add(new Vector2(current.x * gridSize, (current.y * gridSize) + offsetY));
            current = current.parent;
        }

        Collections.reverse(path); // 시작점부터 끝점까지의 경로로 뒤집기
        return path;
    }

    private static class Node {
        int x, y;
        Node parent;
        double g, f;

        Node(int x, int y, Node parent, double g, double f) {
            this.x = x;
            this.y = y;
            this.parent = parent;
            this.g = g;
            this.f = f;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Node)) return false;
            Node node = (Node) o;
            return x == node.x && y == node.y;
        }

        @Override
        public int hashCode() {
            return Objects.hash(x, y);
        }
    }
}