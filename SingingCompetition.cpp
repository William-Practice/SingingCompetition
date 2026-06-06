// SingingCompetition.cpp : 此文件包含 "main" 函数。程序执行将在此处开始并结束。
//

#include <iostream>
#include <vector>
#include <fstream>
#include <string>
#include <algorithm>
#include <iomanip>
#include <numeric> //计算综合需要用Std::accumulate
#include <limits> // for numeric_limits

struct Student {
    int ID;
    std::string name;
    std::vector<int> scores;
    float average;
};

void InputScores(std::vector<Student>& students) {
    std::cout << "输入选手成绩。按Y继续，N停止：\n";
    char choice = 'Y';
    int numberOfJudges = 7;

    while (choice == 'Y' || choice == 'y') {
        Student student;
        student.ID = students.size() + 1;
        std::cout << "选手编号：" << student.ID << "\n";
        std::cout << "姓名：";
        std::getline(std::cin, student.name);

        std::cout << "请输入7位评委的评分：\n";
        for (int i = 0; i < numberOfJudges; ++i) {
            int score;
            std::cout << "评委 " << i + 1 << " 给分：";
            if (!(std::cin >> score)) { std::cin.clear(); std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n'); score = 0; }
            student.scores.push_back(score);
        }
        students.push_back(student);

        std::cout << "继续录入下一个选手? (Y/N): ";
        std::cin >> choice;
        std::cin.ignore(); // 清除缓冲区
    }

    std::ofstream outFile("scores.txt");
    if (!outFile.is_open()) { std::cerr << "无法打开文件 'scores.txt' 进行写入。\n"; return; }
    for (const auto& stu : students) {
        outFile << "ID: " << stu.ID << ", 姓名: " << stu.name << ", 分数: ";
        for (auto score : stu.scores) {
            outFile << score << " ";
        }
        outFile << "\n";
    }
    outFile.close();
}

void CalculateScores(std::vector<Student>& students) {
    for (auto& student : students) {
        if (student.scores.size() < 7) {
            std::cout << "评分数据错误。\n";
            return;
        }
        std::sort(student.scores.begin(), student.scores.end());
        double sum = std::accumulate(student.scores.begin() + 1, student.scores.end() - 1, 0.0);
        student.average = sum / 5.0;
    }

    for (const auto& student : students) {
        std::cout << "ID: " << student.ID << ", 姓名: " << student.name << ", 综合得分: " << std::fixed << std::setprecision(2) << student.average << "\n";
    }
}

void RankStudents(const std::vector<Student>& students) {
    std::vector<Student> sortedStudents = students;
    std::sort(sortedStudents.begin(), sortedStudents.end(),
        [](const Student& a, const Student& b) {
            return a.average > b.average;
        });

    std::cout << "排名结果：\n";
    for (size_t i = 0; i < sortedStudents.size(); ++i) {
        std::cout << "排名 " << i + 1 << ": ID " << sortedStudents[i].ID << ", 姓名 " << sortedStudents[i].name << ", 综合得分 " << std::fixed << std::setprecision(2) << sortedStudents[i].average << "\n";
    }
}

void QueryScores(const std::vector<Student>& students) {
    int id;
    std::cout << "请输入要查询的学号：";
    std::cin >> id;
    auto it = std::find_if(students.begin(), students.end(), [id](const Student& stu) {
        return stu.ID == id;
        });

    if (it != students.end()) {
        std::cout << "ID: " << it->ID << ", 姓名: " << it->name << ", 综合得分: " << std::fixed << std::setprecision(2) << it->average << "\n";
    }
    else {
        std::cout << "未找到该学号的学生。\n";
    }
}

void AnalyzeScoresDistribution(const std::vector<Student>& students) {
    if (students.empty()) {
        std::cout << "没有学生数据可分析。\n";
        return;
    }

    float sum = 0;
    float minScore = std::numeric_limits<float>::max();
    float maxScore = std::numeric_limits<float>::lowest();
    std::vector<float> averages;

    // 收集平均分数并计算最高分和最低分
    for (const auto& student : students) {
        sum += student.average;
        if (student.average < minScore) minScore = student.average;
        if (student.average > maxScore) maxScore = student.average;
        averages.push_back(student.average);
    }

    float mean = sum / students.size();

    // 计算标准差
    float variance = 0;
    for (auto score : averages) {
        variance += (score - mean) * (score - mean);
    }
    float stdDeviation = std::sqrt(variance / students.size());

    // 输出统计结果
    std::cout << "分数分布分析：\n";
    std::cout << "平均分：" << std::fixed << std::setprecision(2) << mean << "\n";
    std::cout << "标准差：" << std::fixed << std::setprecision(2) << stdDeviation << "\n";
    std::cout << "最高分：" << std::fixed << std::setprecision(2) << maxScore << "\n";
    std::cout << "最低分：" << std::fixed << std::setprecision(2) << minScore << "\n";
}

void PublishWinners(std::vector<Student>& students) {
    if (students.size() < 3) {
        std::cout << "参赛学生不足三人，无法发布获奖名单。\n";
        return;
    }

    // 排序，找出成绩前六的学生
    size_t topN = std::min((size_t)6, students.size());
    std::partial_sort(students.begin(), students.begin() + topN, students.end(),
        [](const Student& a, const Student& b) {
            return a.average > b.average;
        });

    std::ofstream outFile("winner.txt");
    if (!outFile.is_open()) { std::cerr << "无法打开文件 'winner.txt' 进行写入。\n"; return; }
    if (!outFile.is_open()) {
        std::cerr << "无法打开文件 'winner.txt' 进行写入。\n";
        return;
    }

    std::cout << "获奖名单如下：\n";
    outFile << "获奖名单如下：\n";

    // 发布获奖名单
    int awards[] = { 1, 2, 3 }; // 奖项数量
    int currentAward = 0;

    for (size_t i = 0; i < topN; ++i) {
        std::string awardName;
        if (i < awards[0]) {
            awardName = "一等奖";
        }
        else if (i < awards[0] + awards[1]) {
            awardName = "二等奖";
        }
        else {
            awardName = "三等奖";
        }

        std::cout << awardName << ": ID " << students[i].ID << ", 姓名 " << students[i].name << ", 综合得分 " << std::fixed << std::setprecision(2) << students[i].average << "\n";
        outFile << awardName << ": ID " << students[i].ID << ", 姓名 " << students[i].name << ", 综合得分 " << std::fixed << std::setprecision(2) << students[i].average << "\n";
    }

    outFile.close();
}

int main() {
    std::vector<Student> students;
    int choice;

    do {
        // system("color 1F"); // removed for safety
        std::cout << "1.参赛选手比赛成绩录入\n2.参赛选手综合成绩计算\n3.参赛选手成绩排名\n4.参赛选手成绩查询\n5.获奖选手名单公布\n6.成绩分布统计分析\n0.退出系统\n选择操作：";
        std::cin >> choice;
        std::cin.ignore();  // 清除缓冲区

        switch (choice) {
        case 1:
            // system("color F0"); // removed for safety
            InputScores(students);
            break;
        case 2:
            // system("color 2F"); // removed for safety
            CalculateScores(students);
            break;
        case 3:
            // system("color 4F"); // removed for safety
            RankStudents(students);
            break;
        case 4:
            // system("color 1E"); // removed for safety
            QueryScores(students);
            break;
        case 5:
            // system("color 6F"); // removed for safety
            PublishWinners(students);
            break;
        case 6:
            // system("color 3F"); // removed for safety
            AnalyzeScoresDistribution(students);
            break;
        case 0:
            // system("color 07"); // removed for safety
            std::cout << "感谢使用！\n";
            break;
        default:
            // system("color 4C"); // removed for safety
            std::cout << "无效选项，请重新输入。\n";
        }
    } while (choice != 0);

    return 0;
}


// 运行程序: Ctrl + F5 或调试 >“开始执行(不调试)”菜单
// 调试程序: F5 或调试 >“开始调试”菜单

// 入门使用技巧: 
//   1. 使用解决方案资源管理器窗口添加/管理文件
//   2. 使用团队资源管理器窗口连接到源代码管理
//   3. 使用输出窗口查看生成输出和其他消息
//   4. 使用错误列表窗口查看错误
//   5. 转到“项目”>“添加新项”以创建新的代码文件，或转到“项目”>“添加现有项”以将现有代码文件添加到项目
//   6. 将来，若要再次打开此项目，请转到“文件”>“打开”>“项目”并选择 .sln 文件
