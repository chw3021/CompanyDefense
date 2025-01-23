package io.github.chw3021.companydefense.pathfinding;

import com.badlogic.gdx.math.Vector2;

import io.github.chw3021.companydefense.obstacle.Obstacle;

import java.util.*;


public class AStarPathfinding {
    private int gridWidth, gridHeight, gridSize;
    private boolean[][] obstacles;

    public AStarPathfinding(int gridWidth, int gridHeight, int gridSize) {
        this.gridWidth = gridWidth;
        this.gridHeight = gridHeight;
        this.gridSize = gridSize;
        this.obstacles = new boolean[gridWidth][gridHeight];
    }

    // 장애물 추가 메서드
    public void addObstacle(int x, int y) {
        if (isValidGrid(x, y)) {
            obstacles[x][y] = true;
        }
    }

    // 장애물을 Stage에서 설정하도록 하는 메서드
    public void setObstacles(Obstacle[][] obstacles) {
        for (int x = 0; x < gridWidth; x++) {
            for (int y = 0; y < gridHeight; y++) {
                if (obstacles[x][y] != null) {
                    addObstacle(x, y);
                }
            }
        }
    }

    public List<Vector2> findPath(int startX, int startY, int targetX, int targetY) {
        PriorityQueue<Node> openList = new PriorityQueue<>(Comparator.comparingDouble(n -> n.f));
        Set<Node> closedList = new HashSet<>();

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
                
                if(newX<0 || newY<0) {
                	continue;
                }

                if (isValidGrid(newX, newY) && !obstacles[newX][newY]) {
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
    	return true;
        //return x >= 0 && y >= 0 && x < gridWidth && y < gridHeight;
    }

    private double heuristic(int x1, int y1, int x2, int y2) {
        return Math.abs(x1 - x2) + Math.abs(y1 - y2); // 맨해튼 거리
    }

    private List<Vector2> reconstructPath(Node node) {
        List<Vector2> path = new ArrayList<>();
        while (node != null) {
            path.add(new Vector2(node.x * gridSize, node.y * gridSize));
            node = node.parent;
        }
        Collections.reverse(path);
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