import contest from "../../lib/contest"
import label from "../../lib/label"
import link from "../../lib/link"
import page from "../../lib/page"
import problem from "../../lib/problem"
import topic from "../../lib/topic"
import {ruen} from "../../lib/util"

export default graph_simple = () ->
    return {
        topic: topic(
            ruen("Проcтые графы", "Simple graphs"),
            ruen("Задачи на простые графы", "Problems on simple graphs"),
        [label(ruen(
             "Теории тут пока нет. Можете прочитать основные вещи <a href=\"https://ru.wikipedia.org/wiki/%D0%93%D1%80%D0%B0%D1%84_(%D0%BC%D0%B0%D1%82%D0%B5%D0%BC%D0%B0%D1%82%D0%B8%D0%BA%D0%B0)\">в википедии</a> (хотя там много лишней терминологии), или <a href=\"https://pythontutor.ru/lessons/graphs/\">здесь</a> (там реализация на питоне, но, я думаю, вы догадаетесь, как это сделать на паскале), или <a href=\"https://school29.smoladmin.ru/arbuzov/vvedenie.html\">здесь</a> (тут несколько страниц). Вам пока надо только понимать, что такое граф, знать ряд определений, и уметь хранить графы в программе. Из способов хранения графа вам пока будет достаточно матрицы смежности, про остальные можете прочитать для сведения. Обходы графа вам пока не нужны (до следующей темы).",
             "You can read the basic things <a href=\"https://en.wikipedia.org/wiki/Graph_(discrete_mathematics)\">in wikipedia</a> (although there is a lot of unnecessary terminology), also many other sites have some basic introduction (e.g. <a href='https://www.geeksforgeeks.org/introduction-to-graphs-data-structure-and-algorithm-tutorials/'>here</a>). For now, you only need to understand what a graph is, know some basic definitions, and be able to store graphs in a program. Of the ways to store the graph, the adjacency matrix and adjacency lists will be enough for you for now. You don't need graph traversals yet (until the next topic).")),
            problem(176),
            problem(177),
            problem(174),
            problem(175),
            problem(474),
            problem(479),
        ], "graphs_simple"),
        advancedProblems: [        
            problem(476),
            problem(1992),
            problem(468),
            problem(470),
        ]
    }