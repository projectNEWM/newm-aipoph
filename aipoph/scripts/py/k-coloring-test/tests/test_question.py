import random

import matplotlib.pyplot as plt
from src.question import create


def test_create_question_and_answer():
    
    # for _ in range(10):
    #     for n in range(3, 42):
    #         print(n)
    #         # n = 30
    #         rng = random.random()
    #         question, answer, minimum = create(n, rng)
    #         # print(question)
    #         # print(answer)
    #         # print(minimum)
            
    #         plt.scatter(n, minimum)
    # plt.savefig('fixed_rng.png')
    plt.savefig('changing_rng.png')
