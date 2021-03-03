
from flask import Flask, request, Response, jsonify
from flask_cors import cross_origin, CORS
import numpy as np
import pandas as pd
from collections import Counter
import json
import re


IGNORE_CHARS = [' ', 'e.g', '.', '?', '!', '...', '\n', "'s", "'",
                ')', ',', ':', '(', '&', '`', '*', '/', '-', ';', '’s']

STOP_WORDS = ['', 'must', 'ourselves', 'hers', 'between', 'yourself', 'but', 'again', 'there', 'about', 'once', 'during', 'out', 'very', 'having', 'with', 'they', 'own', 'an', 'be', 'some', 'for', 'do', 'its', 'yours', 'such', 'into', 'of', 'most', 'itself', 'other', 'off', 'is', 's', 'am', 'or', 'who', 'as', 'from', 'him', 'each', 'the', 'themselves', 'until', 'below', 'are', 'we', 'these', 'your', 'his', 'through', 'don', 'nor', 'me', 'were', 'her', 'more', 'himself', 'this', 'down', 'should', 'our', 'their', 'while',
              'above', 'both', 'up', 'to', 'ours', 'had', 'she', 'all', 'no', 'when', 'at', 'any', 'before', 'them', 'same', 'and', 'been', 'have', 'in', 'will', 'on', 'does', 'yourselves', 'then', 'that', 'because', 'what', 'over', 'why', 'so', 'can', 'did', 'not', 'now', 'under', 'he', 'you', 'herself', 'has', 'just', 'where', 'too', 'only', 'myself', 'which', 'those', 'i', 'after', 'few', 'whom', 't', 'being', 'if', 'theirs', 'my', 'against', 'a', 'by', 'doing', 'it', 'how', 'further', 'was', 'here', 'than', 'etc', 'e.g', 'ex']
CAPITAL_WORD_PATTERN = re.compile('^[A-Z].*[A-Z]+$')
NOT_SPECIAL_WORDS = ['A', 'I', 'U']
SLIENT_VOWELS = ['u', 'e', 'o', 'a', 'i']


def splitSpecialChar(words, chars):
    if len(chars) == 0:
        return words
    # print(words)
    splitChar = chars[0]
    splitedWords = np.array([])

    for word in words:
        splitedWords = np.append(splitedWords, word.split(splitChar))

    if len(chars) == 0:
        return words

    return splitSpecialChar(splitedWords, chars[1:])


def isCapitalLetter(letter):
    return len(letter) == 1 and letter.isupper() and letter not in NOT_SPECIAL_WORDS


def isCapitalWord(word):
    return isCapitalLetter(word) or bool(CAPITAL_WORD_PATTERN.search(word))


def toCapitalWords(words):
    capitalDict = {}

    for word in words:
        if isCapitalWord(word):
            capitalDict[word.lower()] = word

    return capitalDict


def toOriginWord(word, wordDict):
    if word in wordDict.keys():
        return wordDict[word]

    return word


MATCHING_THRESHOLD = 0.45
MIN_REPEAT_TIME = 3
MIN_REPEAT_RATIO = 0.45


def isMaching(word1, word2):
    if (word1 == word2):
        return True

    len1 = len(word1)
    len2 = len(word2)

    j = 0
    comparedLen = min(len1, len2)
    while j < comparedLen:
        if word1[j] == word2[j]:
            j += 1
        else:
            break

    return j / comparedLen > MATCHING_THRESHOLD and j > max(max(len1, len2) * MIN_REPEAT_RATIO, MIN_REPEAT_TIME)


def groupSimilarWord(words):
    n = len(words)
    i = 1
    samesame = np.zeros(n)
    samesame[0] = False

    while i < n:
        preWord = words[i - 1]
        curWord = words[i]

        samesame[i] = isMaching(preWord, curWord)

        i += 1

    # to group index from same same calculate
    i = 0
    groupIdx = 0
    groupMark = np.zeros(n)
    while i < n:
        nextIdx = i + 1
        if nextIdx < len(samesame):
            if samesame[nextIdx]:
                groupMark[i] = groupIdx
            else:
                groupMark[i] = groupIdx
                groupIdx += 1
        else:
            groupMark[i] = groupIdx

        i += 1

    return groupMark


def wordCalculator(text):
    """ Generate number of time that a word happens in text
    Improvement:
    1. return sentence that have give words
    2. Generate word cloud of word's combination (ex. should able detect "data science" instead of understanding only "data" and "science")
    3.
    """
    # tokenize
    rawWords = splitSpecialChar([text], IGNORE_CHARS)
    capitalWords = toCapitalWords(rawWords)

    # lower word
    lowerWords = [word.lower() for word in rawWords]

    # build count table
    wordDF = pd.DataFrame({"word": lowerWords})

    # filter stop word
    wordDF['isStopWord'] = [
        word in STOP_WORDS for word in wordDF['word'].to_list()]
    nonStopWords = wordDF[wordDF['isStopWord'] == False][['word']]

    # comparing the match ratio of two words to merge

    # preprocessing by sorting with alphabet
    alphabetSortedWords = nonStopWords.sort_values(by='word', ascending=True)

    # word grouping by matching prediction
    groups = groupSimilarWord(alphabetSortedWords['word'].to_list())
    alphabetSortedWords['groupMark'] = groups

    originWords = [toOriginWord(word, capitalWords)
                   for word in alphabetSortedWords['word'].to_list()]
    alphabetSortedWords['origin'] = originWords

    words = []
    for row in alphabetSortedWords.values:
        [_, index, word] = row

        i = int(index)
        if len(words) > i:
            if word not in words[i]:
                words[i] += [word]

        else:
            words += [[word]]
    countOnGroup = Counter(groups)

    countDf = pd.DataFrame.from_records(
        list(dict(countOnGroup).items()), columns=["index", "count"])

    countDf['words'] = words

    # sort result by count
    countSort = countDf.sort_values(by='count', ascending=False)

    return countSort[['words', 'count']]

###


app = Flask(__name__)
CORS(app)


@app.route('/')
def hello():
    return "Server is running"


@app.route('/wordcloud', methods=['POST'])
def worldcloudGenerator():
    # get value of field text
    text = request.form['text']
    print(text)

    # calculate term weights
    wordCount = wordCalculator(text)

    # build response
    body = {
        'data': wordCount.to_dict(orient="records"),
        'message': 'Wordcloud is generated successfully',
        'success': True,
    }
    res = jsonify(body)
    return res


if __name__ == '__main__':
    app.run(port=5050, host='0.0.0.0', debug=True)
    # app.run(debug=True)
