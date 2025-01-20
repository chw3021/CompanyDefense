package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;
import com.badlogic.gdx.math.Vector2;
import java.util.List;

public class PathfindingComponent implements Component {
    public List<Vector2> path; // A* 경로 결과
    public int pathIndex = 0;  // 현재 경로 인덱스
    public Vector2 target;    // 목표 위치
    public boolean avoidObstacles = true; // 장애물 회피 여부
}