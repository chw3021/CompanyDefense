package io.github.chw3021.companydefense.pathfinding;

import com.badlogic.ashley.core.Entity;
import com.badlogic.ashley.core.Family;
import com.badlogic.ashley.systems.IteratingSystem;
import com.badlogic.gdx.math.Vector2;

import io.github.chw3021.companydefense.component.PathfindingComponent;
import io.github.chw3021.companydefense.component.TransformComponent;

public class PathfindingSystem extends IteratingSystem {
    private int gridSize;
    private int gridWidth;
    private int gridHeight;

    public PathfindingSystem(int gridWidth, int gridHeight, int gridSize) {
        super(Family.all(TransformComponent.class, PathfindingComponent.class).get());
        this.gridWidth = gridWidth;
        this.gridHeight = gridHeight;
        this.gridSize = gridSize;
    }

    @Override
    protected void processEntity(Entity entity, float deltaTime) {
        TransformComponent transform = entity.getComponent(TransformComponent.class);
        PathfindingComponent pathfinding = entity.getComponent(PathfindingComponent.class);

        // 목표가 설정되지 않은 경우 처리하지 않음
        if (pathfinding.target == null) return;

        // 경로를 아직 계산하지 않은 경우 A* 알고리즘 실행
        if (pathfinding.path == null || pathfinding.path.isEmpty()) {
            AStarPathfinding aStar = new AStarPathfinding(gridWidth, gridHeight, gridSize);
            
            // 장애물 추가 (게임 환경에서 얻어와야 함)
            // 예: aStar.addObstacle(3, 4);
            
            pathfinding.path = aStar.findPath(
                (int) (transform.position.x / gridSize), 
                (int) (transform.position.y / gridSize), 
                (int) (pathfinding.target.x / gridSize), 
                (int) (pathfinding.target.y / gridSize)
            );
            pathfinding.pathIndex = 0; // 경로 초기화
        }

        // 경로를 따라 이동
        if (pathfinding.path != null && pathfinding.pathIndex < pathfinding.path.size()) {
            Vector2 nextPoint = pathfinding.path.get(pathfinding.pathIndex);
            Vector2 direction = new Vector2(nextPoint).sub(transform.position).nor();
            
            // 장애물 회피
            if (pathfinding.avoidObstacles) {
                avoidObstacles(entity, direction);
            }

            // 이동 업데이트
            transform.velocity.set(direction.scl(transform.moveSpeed));
            transform.position.add(transform.velocity.x * deltaTime, transform.velocity.y * deltaTime);

            // 다음 지점 도달 확인
            if (transform.position.dst(nextPoint) < 5) { // 5는 도달 기준 거리
                pathfinding.pathIndex++;
            }
        }
    }

    private void avoidObstacles(Entity entity, Vector2 direction) {
        // 장애물 회피 로직 (단순화된 예제)
        // 실제로는 주변 장애물을 탐지하고 방향을 변경
    }
}
