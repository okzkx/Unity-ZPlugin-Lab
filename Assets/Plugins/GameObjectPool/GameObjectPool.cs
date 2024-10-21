using System;
using System.Collections.Generic;
using UnityEngine;

public class GameObjectPool {
    private Stack<GameObject> stack;

    public Func<GameObject> Create;

    public T Get<T>() {
        if (stack.TryPop(out GameObject gameObject)) {
            if (gameObject != null) {
                gameObject.SetActive(true);
                return gameObject.GetComponent<T>();
            }
            else {
                return Get<T>();
            }
        }

        gameObject = Create();
        gameObject.SetActive(true);

        return gameObject.GetComponent<T>();
    }

    public void Release(GameObject gameObject) {
        gameObject.SetActive(false);
        stack.Push(gameObject);
    }
}