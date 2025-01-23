package io.github.chw3021.companydefense.component;

import com.badlogic.ashley.core.Component;
import com.badlogic.gdx.math.Vector2;
import java.util.List;

public class PathfindingComponent implements Component {
    public List<Vector2> path; // A* 경로 결과
    public int pathIndex = 0;  // 현재 경로 인덱스
    public Vector2 target;    // 목표 위치
    public boolean avoidObstacles = true; // 장애물 회피 여부
	public List<Vector2> getPath() {
		return path;
	}
	public void setPath(List<Vector2> path) {
		this.path = path;
	}
	public int getPathIndex() {
		return pathIndex;
	}
	public void setPathIndex(int pathIndex) {
		this.pathIndex = pathIndex;
	}
	public Vector2 getTarget() {
		return target;
	}
	public void setTarget(Vector2 target) {
		this.target = target;
	}
	public boolean isAvoidObstacles() {
		return avoidObstacles;
	}
	public void setAvoidObstacles(boolean avoidObstacles) {
		this.avoidObstacles = avoidObstacles;
	}
    
    
}