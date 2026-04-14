import tkinter as tk
import random
import time

# --- CONFIGURATION ---
CELL_SIZE = 30
COLS, ROWS = 8, 19  # 19 Rows for perfect breathing room
BOARD_WIDTH, BOARD_HEIGHT = COLS * CELL_SIZE, ROWS * CELL_SIZE
UI_WIDTH = 300
WIDTH, HEIGHT = BOARD_WIDTH + UI_WIDTH, BOARD_HEIGHT

# Shapes and Colors
SHAPES = [
    [(0, -1), (0, 0), (0, 1)],    # 0: I-King
    [(0, -1), (0, 0), (1, 0)],    # 1: L-King
    [(-1, -1), (0, 0), (1, 1)],   # 2: D-King
    [(-1, -1), (0, 0), (1, -1)],  # 3: V-King
    [(0, -1), (0, 0), (-1, 1)],   # 4: J-Hook
    [(0, -1), (0, 0), (1, 1)]     # 5: L-Hook
]
COLORS = ["#00FFFF", "#FFA500", "#FF00FF", "#00FF00", "#0000FF", "#FF0000"]
BG_COLOR, GRID_COLOR, UI_BG = "#0f0f0f", "#282828", "#1a1a1a"

class Piece:
    def __init__(self, shape_idx):
        self.id = shape_idx
        self.shape = [list(p) for p in SHAPES[shape_idx]]
        self.color = COLORS[shape_idx]
        self.x, self.y = COLS // 2, 1

    def rotate(self, board):
        new_shape = [[-by, bx] for bx, by in self.shape]
        for kx, ky in [(0,0), (1,0), (-1,0), (0,-1), (1,-1), (-1,-1)]:
            valid = True
            for bx, by in new_shape:
                test_x, test_y = self.x + bx + kx, self.y + by + ky
                if test_x < 0 or test_x >= COLS or test_y >= ROWS or (test_y >= 0 and board[test_y][test_x] != 0):
                    valid = False; break
            if valid:
                self.shape, self.x, self.y = new_shape, self.x + kx, self.y + ky
                return

class Game:
    def __init__(self):
        self.board = [[0] * COLS for _ in range(ROWS)]
        self.bag = []
        self.next_queue = [self.get_next_shape() for _ in range(3)]
        self.piece = Piece(self.pop_next_piece())
        
        self.score, self.lines, self.level = 0, 0, 1
        self.game_over = False
        self.last_fall_time = time.time()

    def get_next_shape(self):
        if not self.bag:
            # Weighted Bag: 2 I-Kings, 2 L-Kings, 1 of everything else
            self.bag = [0, 0, 1, 1, 2, 3, 4, 5]
            random.shuffle(self.bag)
        return self.bag.pop()

    def pop_next_piece(self):
        next_id = self.next_queue.pop(0)
        self.next_queue.append(self.get_next_shape())
        return next_id

    def valid_move(self, dx, dy):
        for bx, by in self.piece.shape:
            px, py = self.piece.x + bx + dx, self.piece.y + by + dy
            if px < 0 or px >= COLS or py >= ROWS or (py >= 0 and self.board[py][px] != 0): return False
        return True

    def get_ghost_y(self):
        ghost_y = self.piece.y
        while True:
            valid = True
            for bx, by in self.piece.shape:
                px, py = self.piece.x + bx, ghost_y + by + 1
                if py >= ROWS or (py >= 0 and self.board[py][px] != 0): valid = False; break
            if valid: ghost_y += 1
            else: break
        return ghost_y

    def lock_piece(self):
        for bx, by in self.piece.shape:
            px, py = self.piece.x + bx, self.piece.y + by
            if py < 0: self.game_over = True
            else: self.board[py][px] = self.piece.color
        
        self.check_lines()
        if not self.game_over:
            self.piece = Piece(self.pop_next_piece())
            if not self.valid_move(0, 0): self.game_over = True

    def check_lines(self):
        lines_to_clear = []
        for y in range(ROWS):
            if all(self.board[y][x] != 0 for x in range(COLS)):
                lines_to_clear.append(y)
                
        cleared = len(lines_to_clear)
        if cleared > 0:
            for clear_y in lines_to_clear:
                for y in range(clear_y, 0, -1): self.board[y] = self.board[y-1][:]
                self.board[0] = [0] * COLS
            
            scores = {1: 100, 2: 300, 3: 500}
            self.score += scores.get(cleared, 0) * self.level
            self.lines += cleared
            self.level = (self.lines // 10) + 1

    def update_fall(self):
        current_time = time.time()
        # Forgiving Gravity Curve: max speed cap of 0.1s
        speed = max(0.1, 0.6 - ((self.level - 1) * 0.03))
        if current_time - self.last_fall_time >= speed:
            self.last_fall_time = current_time
            if self.valid_move(0, 1): self.piece.y += 1
            else: self.lock_piece()

class TriKingsApp:
    def __init__(self, root):
        self.root = root
        self.root.title("TriKing")
        self.canvas = tk.Canvas(root, width=WIDTH, height=HEIGHT, bg=BG_COLOR, highlightthickness=0)
        self.canvas.pack()

        self.state = "menu"  # NEW: menu, playing, paused
        self.game = None

        self.root.bind("<Key>", self.handle_input)
        self.game_loop()

    def start_game(self):
        self.game = Game()
        self.state = "playing"

    def toggle_pause(self):
        if self.state == "playing":
            self.state = "paused"
        elif self.state == "paused":
            self.state = "playing"

    def handle_input(self, event):
        # --- MENU CONTROLS ---
        if self.state == "menu":
            if event.keysym == "Return":  # Enter to start
                self.start_game()
            return

        # --- PAUSE CONTROL ---
        if event.keysym.lower() == "p":
            self.toggle_pause()
            return

        # --- IGNORE INPUT IF PAUSED OR GAME OVER ---
        if self.state != "playing" or self.game.game_over:
            return

        # --- GAME CONTROLS ---
        if event.keysym == 'Left' and self.game.valid_move(-1, 0):
            self.game.piece.x -= 1
        elif event.keysym == 'Right' and self.game.valid_move(1, 0):
            self.game.piece.x += 1
        elif event.keysym == 'Down' and self.game.valid_move(0, 1): 
            self.game.piece.y += 1
            self.game.score += 1
        elif event.keysym == 'Up':
            self.game.piece.rotate(self.game.board)
        elif event.keysym == 'space':
            drop_distance = 0
            while self.game.valid_move(0, 1):
                self.game.piece.y += 1
                drop_distance += 2
            self.game.score += drop_distance
            self.game.lock_piece()
            self.game.last_fall_time = time.time()

        self.draw()

    def draw_menu(self):
        self.canvas.delete("all")
        self.canvas.create_text(WIDTH//2, HEIGHT//2 - 40,
                                text="TriKing",
                                fill="white",
                                font=("Arial", 32, "bold"))
        self.canvas.create_text(WIDTH//2, HEIGHT//2 + 20,
                                text="Press ENTER to Start",
                                fill="gray",
                                font=("Arial", 16))

    def draw_pause(self):
        self.canvas.create_text(BOARD_WIDTH//2, HEIGHT//2,
                                text="PAUSED",
                                fill="white",
                                font=("Arial", 28, "bold"))

    def draw(self):
        if self.state == "menu":
            self.draw_menu()
            return

        self.canvas.delete("all")
        self.draw_ui()

        # Draw Board
        for x in range(COLS):
            for y in range(ROWS):
                x1, y1 = (x * CELL_SIZE), y * CELL_SIZE
                x2, y2 = x1 + CELL_SIZE, y1 + CELL_SIZE
                self.canvas.create_rectangle(x1, y1, x2, y2, outline=GRID_COLOR)
                if self.game.board[y][x] != 0:
                    self.canvas.create_rectangle(x1, y1, x2, y2,
                                                 fill=self.game.board[y][x],
                                                 outline=GRID_COLOR)

        if not self.game.game_over:
            # Ghost
            ghost_y = self.game.get_ghost_y()
            for bx, by in self.game.piece.shape:
                px, py = self.game.piece.x + bx, ghost_y + by
                if py >= 0:
                    x1, y1 = (px * CELL_SIZE), py * CELL_SIZE
                    self.canvas.create_rectangle(x1, y1,
                                                 x1 + CELL_SIZE, y1 + CELL_SIZE,
                                                 fill="", outline=self.game.piece.color, width=2)

            # Active piece
            for bx, by in self.game.piece.shape:
                px, py = self.game.piece.x + bx, self.game.piece.y + by
                if py >= 0:
                    x1, y1 = (px * CELL_SIZE), py * CELL_SIZE
                    self.canvas.create_rectangle(x1, y1,
                                                 x1 + CELL_SIZE, y1 + CELL_SIZE,
                                                 fill=self.game.piece.color,
                                                 outline=GRID_COLOR)

        if self.state == "paused":
            self.draw_pause()

        if self.game.game_over:
            self.canvas.create_text((BOARD_WIDTH//2), HEIGHT//2,
                                    text="GAME OVER",
                                    fill="white",
                                    font=("Arial", 28, "bold"))

    def draw_mini_piece(self, piece_id, cx, cy):
        if piece_id is None: return
        shape = SHAPES[piece_id]
        color = COLORS[piece_id]
        m_size = CELL_SIZE * 0.7 
        for bx, by in shape:
            px, py = cx + (bx * m_size), cy + (by * m_size)
            self.canvas.create_rectangle(px, py, px+m_size, py+m_size,
                                         fill=color, outline=GRID_COLOR)

    def draw_ui(self):
        offset_x = BOARD_WIDTH
        self.canvas.create_rectangle(offset_x, 0, WIDTH, HEIGHT, fill=UI_BG, outline="")
        self.canvas.create_text(offset_x + UI_WIDTH//2, 30, text="NEXT", fill="white", font=("Arial", 14, "bold"))
        self.canvas.create_rectangle(offset_x + 25, 50, offset_x + UI_WIDTH - 25, 270, outline="gray")
        
        for i, p_id in enumerate(self.game.next_queue):
            self.draw_mini_piece(p_id, offset_x + (UI_WIDTH//2) - 10, 80 + (i * 70))

        self.canvas.create_text(offset_x + UI_WIDTH//2, 340,
                                text=f"SCORE\n{self.game.score}",
                                fill="white", font=("Arial", 14, "bold"),
                                justify="center")
        self.canvas.create_text(offset_x + UI_WIDTH//2, 410,
                                text=f"LEVEL\n{self.game.level}",
                                fill="white", font=("Arial", 14, "bold"),
                                justify="center")
        self.canvas.create_text(offset_x + UI_WIDTH//2, 480,
                                text=f"LINES\n{self.game.lines}",
                                fill="white", font=("Arial", 14, "bold"),
                                justify="center")

    def game_loop(self):
        if self.state == "playing" and not self.game.game_over:
            self.game.update_fall()

        self.draw()
        self.root.after(16, self.game_loop)

if __name__ == "__main__":
    root = tk.Tk()
    root.resizable(False, False)
    TriKingsApp(root)
    root.mainloop()
