import label from "../../lib/label"
import level from "../../lib/level"
import problem from "../../lib/problem"
import topic from "../../lib/topic"

topic19011 = () ->
    return topic("Применения сортировки", "5Б: Задачи на применение сортировок", [
        label("<h4>Применения сортировки</h4>\n<p>Теории тут нет, спросите на занятии</p>"),
        problem(411),
        problem(734),
        problem(1130),
        problem(1744),
        problem(2978),
    ])

topic19009 = () ->
    return topic("Рекурсивный перебор", "5Б: Задачи на рекурсивный перебор", [
        label("<h4>Рекурсивный перебор</h4>\n<p>Для тех, кто не изучал или не понял эту тему на уровне 2А, теперь она обязательна. Теория есть на уровне 2А.</p>"),
        problem(80),
        problem(84),
        problem(85),
        problem(89),
        problem(90),
        problem(91),
        problem(485),
        problem(1182),
    ])

topic17297 = () ->
    return topic("Продвинутый алгоритм Дейкстры", "5Б: Задачи на алгоритм Дейкстры с кучей", [
        label("<h4>Продвинутый алгоритм Дейкстры</h4>"),
        label("См. <a href=\"http://sis.khashaev.ru/2013/july/b-prime/JbeOdEYcQ2Y/\">видеозаписи лекций ЛКШ.2013.B'</a>, раздел \"Алгоритм Дейкстры поиска кратчайших путей. Использование кучи.\""),
        problem(3494),
        problem(1745),
        problem(1087),
    ])

topic17241 = () ->
    return topic("Куча", "5Б: Задачи на кучу", [
        label("<h4>Куча</h4>"),
        label("См. <a href=\"http://sis.khashaev.ru/2013/july/b-prime/\">видеозаписи лекций ЛКШ.2013.B'</a>, раздел \"Куча\"<br>\nСм. <a href=\"http://sis.khashaev.ru/2008/august/b-prime/\">видеозаписи лекций ЛКШ.2008.B'</a>, раздел \"Куча\""),
        problem(755),
        problem(756),
        problem(489),
    ])

export default level_5B = () ->
    return level("5Б", [
        label("Чтобы перейти на следующий уровень, надо решить все задачи."),
        topic17241(),
        topic17297(),
        topic19009(),
        topic19011(),
    ])