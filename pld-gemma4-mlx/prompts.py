"""Three prompt classes used in the PLD bench.

  - passage:  long-context passage + summarization question (proxies classic doc RAG)
  - code:     a partially-implemented Vector2D module (proxies code RAG)
  - json_rag: a list of structured employee records + add-a-record request
              (proxies structured / JSON RAG)

Extracted from fork_4/phase_a_pld/bench_phase_a.py for the public release.
"""

from __future__ import annotations

_PASSAGE_PROMPT = """Below is a long passage on the history of computing. After the passage,
respond to the question that follows.

The history of computing is the story of how humans have used tools to perform
calculations and process information. From the abacus to modern supercomputers,
the development of computing devices has fundamentally shaped human civilization.
The earliest known computing devices were simple counting tools used by ancient
civilizations. The abacus, invented around 2500 BCE in Mesopotamia, allowed
merchants and mathematicians to perform basic arithmetic operations. Roman
numerals and the development of zero by Indian mathematicians in the 5th century
laid the groundwork for modern arithmetic. In the 17th century, mechanical
calculators began to emerge. Wilhelm Schickard built a calculating clock in 1623,
and Blaise Pascal invented the Pascaline in 1642. Gottfried Wilhelm Leibniz
improved upon these designs with his stepped reckoner in 1672. The 19th century
brought significant advances. Charles Babbage designed the Difference Engine and
Analytical Engine, conceptual machines that contained the basic elements of
modern computers. Ada Lovelace, working with Babbage, wrote what is considered
the first computer program. The early 20th century saw the development of
electromechanical calculators. Herman Hollerith's tabulating machine, used in
the 1890 US Census, demonstrated the practical value of automated data
processing. His company would later become IBM. Alan Turing's theoretical work
in the 1930s established the foundations of computer science. His concept of a
universal machine that could simulate any other machine was revolutionary. The
invention of the transistor at Bell Labs in 1947 transformed electronics. The
first electronic computers, such as ENIAC and Colossus, were enormous machines
that filled entire rooms. They used vacuum tubes and consumed enormous amounts
of power. The development of integrated circuits in the 1950s and 1960s allowed
computers to become smaller and more powerful. The microprocessor, invented in
1971 by Intel, made personal computers possible. Companies like Apple, IBM, and
Microsoft revolutionized the industry in the late 1970s and 1980s. The rise of
the internet in the 1990s connected computers worldwide and transformed how
people communicate and access information. The 21st century has seen the
emergence of mobile computing, cloud services, and artificial intelligence.

Question: Briefly summarize the key milestones in the history of computing,
focusing on the transition from mechanical to electronic devices.

Answer: """


# A self-contained Python source file that defines a Vector2D class with
# the obvious arithmetic methods, plus a partially-implemented helper at
# the bottom. The model's continuation is highly likely to repeat
# identifiers (`self.x`, `self.y`, `Vector2D`, `return Vector2D(...)`)
# verbatim, which is precisely the regime PLD shines in.
_CODE_PROMPT = '''"""vector2d.py — a tiny 2D vector library.

This module implements a small Vector2D class with the standard
arithmetic operators, a few geometric helpers, and a parser for
"x,y" strings. The implementations are deliberately verbose so that
common identifiers (``self.x``, ``self.y``, ``Vector2D``, ``return``)
recur many times — this exercises prompt-lookup decoding, where the
draft tokens come from suffix matches in the prompt history.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass
class Vector2D:
    """A 2D vector with float components ``x`` and ``y``."""

    x: float
    y: float

    def __add__(self, other: "Vector2D") -> "Vector2D":
        if not isinstance(other, Vector2D):
            return NotImplemented
        return Vector2D(self.x + other.x, self.y + other.y)

    def __sub__(self, other: "Vector2D") -> "Vector2D":
        if not isinstance(other, Vector2D):
            return NotImplemented
        return Vector2D(self.x - other.x, self.y - other.y)

    def __mul__(self, scalar: float) -> "Vector2D":
        if not isinstance(scalar, (int, float)):
            return NotImplemented
        return Vector2D(self.x * scalar, self.y * scalar)

    def __rmul__(self, scalar: float) -> "Vector2D":
        return self.__mul__(scalar)

    def __truediv__(self, scalar: float) -> "Vector2D":
        if not isinstance(scalar, (int, float)):
            return NotImplemented
        if scalar == 0:
            raise ZeroDivisionError("Vector2D division by zero scalar")
        return Vector2D(self.x / scalar, self.y / scalar)

    def __neg__(self) -> "Vector2D":
        return Vector2D(-self.x, -self.y)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Vector2D):
            return NotImplemented
        return self.x == other.x and self.y == other.y

    def dot(self, other: "Vector2D") -> float:
        return self.x * other.x + self.y * other.y

    def cross(self, other: "Vector2D") -> float:
        return self.x * other.y - self.y * other.x

    def length(self) -> float:
        return math.sqrt(self.x * self.x + self.y * self.y)

    def length_squared(self) -> float:
        return self.x * self.x + self.y * self.y

    def normalized(self) -> "Vector2D":
        l = self.length()
        if l == 0:
            raise ValueError("cannot normalize zero-length Vector2D")
        return Vector2D(self.x / l, self.y / l)


def parse_vector(text: str) -> Vector2D:
    """Parse a string of the form ``"x,y"`` into a Vector2D."""
    parts = text.strip().split(",")
    if len(parts) != 2:
        raise ValueError(f"expected 'x,y', got: {text!r}")
    x = float(parts[0])
    y = float(parts[1])
    return Vector2D(x, y)


def distance(a: Vector2D, b: Vector2D) -> float:
    """Return the Euclidean distance between two Vector2D points."""
    return (a - b).length()


# TODO: implement ``midpoint`` — return the midpoint of two Vector2D points.
# It must take two Vector2D arguments named ``a`` and ``b`` and return a
# Vector2D whose components are the arithmetic mean of the inputs.
def midpoint(a: Vector2D, b: Vector2D) -> Vector2D:
    """Return the midpoint of two Vector2D points ``a`` and ``b``."""
'''


# A JSON-RAG-style prompt: ~800 tokens of records with consistent schema
# followed by a request to add a new record. Field names ("name", "age",
# "department", "salary", "start_date", "skills") recur in every record,
# so PLD should hit very high acceptance on the field-name tokens.
_JSON_RAG_PROMPT = '''Below is a JSON list of employee records. After the list,
add one new record matching the same schema for the description that follows.

[
  {
    "id": 1001,
    "name": "Alice Chen",
    "age": 34,
    "department": "Engineering",
    "title": "Senior Software Engineer",
    "salary": 165000,
    "start_date": "2019-03-15",
    "manager_id": 2001,
    "skills": ["python", "rust", "distributed systems"],
    "office": "San Francisco",
    "remote": false
  },
  {
    "id": 1002,
    "name": "Bob Martinez",
    "age": 41,
    "department": "Engineering",
    "title": "Staff Engineer",
    "salary": 210000,
    "start_date": "2015-08-22",
    "manager_id": 2001,
    "skills": ["c++", "kernel", "compilers"],
    "office": "San Francisco",
    "remote": false
  },
  {
    "id": 1003,
    "name": "Carol Nguyen",
    "age": 29,
    "department": "Design",
    "title": "Product Designer",
    "salary": 135000,
    "start_date": "2021-06-01",
    "manager_id": 2002,
    "skills": ["figma", "user research", "prototyping"],
    "office": "New York",
    "remote": true
  },
  {
    "id": 1004,
    "name": "David Okonkwo",
    "age": 37,
    "department": "Data",
    "title": "Senior Data Scientist",
    "salary": 175000,
    "start_date": "2018-11-12",
    "manager_id": 2003,
    "skills": ["python", "sql", "statistics", "ml"],
    "office": "Remote",
    "remote": true
  },
  {
    "id": 1005,
    "name": "Elena Rossi",
    "age": 45,
    "department": "Engineering",
    "title": "Engineering Director",
    "salary": 280000,
    "start_date": "2012-02-08",
    "manager_id": null,
    "skills": ["leadership", "architecture", "mentoring"],
    "office": "San Francisco",
    "remote": false
  },
  {
    "id": 1006,
    "name": "Frank Tanaka",
    "age": 31,
    "department": "Engineering",
    "title": "Software Engineer",
    "salary": 145000,
    "start_date": "2020-09-30",
    "manager_id": 2001,
    "skills": ["go", "kubernetes", "infrastructure"],
    "office": "Seattle",
    "remote": false
  },
  {
    "id": 1007,
    "name": "Grace Patel",
    "age": 38,
    "department": "Product",
    "title": "Senior Product Manager",
    "salary": 195000,
    "start_date": "2016-04-19",
    "manager_id": 2004,
    "skills": ["roadmapping", "user research", "analytics"],
    "office": "New York",
    "remote": true
  }
]

Add a new record with id 1008 for: Henry Lindqvist, age 33, an Engineering
Manager hired on 2017-07-05, who reports to manager_id 2001, makes 220000,
is based in Stockholm working remote, and whose skills are leadership,
golang, and observability.

New record:
'''


PROMPTS = {
    "passage": _PASSAGE_PROMPT,
    "code": _CODE_PROMPT,
    "json_rag": _JSON_RAG_PROMPT,
}
