# 実行モード実装仕様書

## 概要

アプリの最初の実装フェーズ。ユーザーが日々のタスク・習慣を報告し、AI がそれを推測判定する機能に特化。
Onboarding データはモック（JSON ファイルまたは DB に事前登録）として準備される。

---

## 1. 実行モードの責務

### 1.1 ユーザー入力の処理

```
入力：ユーザーがメッセージを入力
  ↓
[NLP解析]
  - テキストから習慣・タスクを抽出
  - 関連する習慣 ID を特定
  ↓
[実行判定]
  - ExecutionInference を生成
  - completionPercentage を計算
  ↓
[データ記録]
  - Message を保存
  - HabitExecution または Task を記録
  ↓
[AI応答生成]
  - シンプルで簡潔な応答
  - 次のアクション提案（オプション）
  ↓
[バックグラウンド処理]
  - チェーン整合性チェック
  - Onboarding キュー更新
  - 統計情報更新
```

### 1.2 実行モードで「やらない」こと

- ❌ Onboarding モードへの自動遷移
- ❌ 詳細な習慣再検討
- ❌ 複雑な分析や推奨
- ❌ 重い DB 処理

---

## 2. データモデル（実行モード関連）

### 2.1 最小限の必須テーブル

```sql
-- ユーザー基本情報
CREATE TABLE users (
  id UUID PRIMARY KEY,
  username VARCHAR NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- メッセージ（会話ログ）
CREATE TABLE messages (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  conversation_id UUID NOT NULL,
  sender ENUM('user', 'assistant') NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  related_habits JSONB,
  related_chains JSONB
);

-- 習慣定義（モックデータから読み込み）
CREATE TABLE habits (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR NOT NULL,
  description TEXT,
  target_frequency VARCHAR,
  parent_habit_id UUID REFERENCES habits(id),
  level INTEGER DEFAULT 0,
  completion_logic JSONB,
  importance FLOAT,
  importance_inferred FLOAT,
  hidden_parameters JSONB,
  is_archived BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- チェーン定義（モックデータから読み込み）
CREATE TABLE habit_chains (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  trigger_habits UUID[] NOT NULL,
  prerequisite_habits JSONB,
  next_habit_id UUID NOT NULL REFERENCES habits(id),
  delay_minutes INTEGER DEFAULT 0,
  trigger_condition JSONB NOT NULL,
  is_automatic BOOLEAN DEFAULT FALSE,
  confidence FLOAT,
  frequency INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 習慣実行ログ
CREATE TABLE habit_executions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  habit_id UUID NOT NULL REFERENCES habits(id),
  message_id UUID NOT NULL REFERENCES messages(id),
  execution_type ENUM('direct', 'partial', 'inferred') NOT NULL,
  completion_percentage INTEGER,
  executed_at TIMESTAMP NOT NULL,
  days_chain INTEGER DEFAULT 0,
  is_parallel_execution BOOLEAN DEFAULT FALSE,
  parallel_with UUID[],
  created_at TIMESTAMP DEFAULT NOW()
);

-- タスク（単発タスク）
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  message_id UUID NOT NULL REFERENCES messages(id),
  name VARCHAR NOT NULL,
  description TEXT,
  task_type ENUM('occasional', 'contextual') NOT NULL,
  related_habits UUID[],
  is_parallel_execution BOOLEAN DEFAULT FALSE,
  parallel_with UUID[],
  executed_at TIMESTAMP NOT NULL,
  is_included_in_report BOOLEAN DEFAULT TRUE,
  is_onboarding_candidate BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- AI推測ログ
CREATE TABLE execution_inferences (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  message_id UUID NOT NULL REFERENCES messages(id),
  user_input TEXT NOT NULL,
  inferred_habits JSONB NOT NULL,
  chain_consistency_check JSONB,
  proactive_questions JSONB,
  user_feedback JSONB,
  debug_info JSONB,
  ai_learning_applied JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Onboarding キュー
CREATE TABLE queued_onboarding_questions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  current_interview_version INTEGER,
  questions_queue JSONB NOT NULL,
  total_questions INTEGER,
  answered_count INTEGER DEFAULT 0,
  last_updated_at TIMESTAMP DEFAULT NOW()
);
```

### 2.2 モックデータ構造

Akira用のモックデータ（JSON形式で事前登録）：

```json
{
  "user": {
    "id": "user-akira-001",
    "username": "akira",
    "created_at": "2025-01-01T00:00:00Z"
  },
  "interview": {
    "id": "interview-akira-001",
    "version": 1,
    "habits": [
      {
        "id": "habit-wakeup-001",
        "name": "朝7時起床",
        "description": "平日、7時～7時15分に起床する",
        "target_frequency": "daily",
        "level": 0,
        "completion_logic": {
          "type": "direct",
          "value": 100
        },
        "importance_inferred": 0.7,
        "hidden_parameters": {
          "rigidityLevel": 0.8,
          "contextualTriggers": ["子どもの登園準備が必要になる時刻"],
          "seasonalVariation": true,
          "toleranceForFailure": 0.3,
          "emotionalSignificance": 0.6,
          "userRealisticExpectation": 0.8,
          "externalPressure": 0.85,
          "existingMomentum": 0.85
        }
      },
      {
        "id": "habit-washing-001",
        "name": "洗顔・身だしなみ",
        "description": "顔を洗う、歯を磨く、身支度",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 10,
        "importance_inferred": 0.55,
        "hidden_parameters": {
          "rigidityLevel": 0.4,
          "toleranceForFailure": 0.7,
          "userRealisticExpectation": 0.5,
          "emotionalSignificance": 0.4
        }
      },
      {
        "id": "habit-coffee-001",
        "name": "コーヒーボタンON",
        "description": "前夜に準備してあるコーヒーメーカーのボタンを押す",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 2,
        "importance_inferred": 0.65
      },
      {
        "id": "habit-stretch-001",
        "name": "ストレッチ（軽く）",
        "description": "軽いストレッチ、可能であれば実施",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 5,
        "importance_inferred": 0.35,
        "hidden_parameters": {
          "rigidityLevel": 0.3,
          "toleranceForFailure": 0.8,
          "emotionalSignificance": 0.4,
          "userRealisticExpectation": 0.4
        }
      },
      {
        "id": "habit-breakfast-001",
        "name": "子どもの朝ごはん準備",
        "description": "子どもの朝食を準備し、一緒に食べさせる",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 20,
        "importance_inferred": 0.95,
        "hidden_parameters": {
          "rigidityLevel": 0.95,
          "toleranceForFailure": 0.05,
          "externalPressure": 0.95,
          "emotionalSignificance": 0.9
        }
      },
      {
        "id": "habit-sendoff-001",
        "name": "登園準備・送迎",
        "description": "子どもの身支度をして、8時15分～8時45分に登園に送迎",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 30
      },
      {
        "id": "habit-my-breakfast-001",
        "name": "自分の朝食",
        "description": "登園送迎後、自分の朝食を準備・摂取",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 15
      },
      {
        "id": "habit-work-start-001",
        "name": "仕事開始（9時30分）",
        "description": "リモートワークの業務開始",
        "target_frequency": "weekdays",
        "level": 0
      },
      {
        "id": "habit-child-sleep-001",
        "name": "子どもを寝かしつける",
        "description": "22時頃に子どもを寝かしつける",
        "target_frequency": "daily",
        "level": 0,
        "estimated_time_minutes": 30
      },
      {
        "id": "habit-night-sleep-001",
        "name": "夜23時就寝（基本）",
        "description": "23時に就寝する（基本的なリズム）",
        "target_frequency": "daily",
        "level": 0,
        "importance_inferred": 0.75
      },
      {
        "id": "habit-idol-watch-001",
        "name": "アイドル配信視聴（週1回）",
        "description": "毎日開催されるアイドル配信のうち、週1回程度視聴する",
        "target_frequency": "weekly",
        "level": 0,
        "importance_inferred": 0.8,
        "hidden_parameters": {
          "emotionalSignificance": 0.9,
          "existingMomentum": 0.95
        }
      },
      {
        "id": "habit-split-sleep-001",
        "name": "分割睡眠（配信ある日）",
        "description": "23時就寝 → 25時起床 → 配信視聴（26時～27時半頃） → 28時に再就寝",
        "target_frequency": "weekly",
        "level": 0
      }
    ],
    "chains": [
      {
        "id": "chain-morning-001",
        "trigger_habits": ["habit-wakeup-001"],
        "next_habit_id": "habit-washing-001",
        "delay_minutes": 0,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 0
        }
      },
      {
        "id": "chain-morning-002",
        "trigger_habits": ["habit-washing-001"],
        "next_habit_id": "habit-coffee-001",
        "delay_minutes": 5,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 5
        }
      },
      {
        "id": "chain-morning-003",
        "trigger_habits": ["habit-coffee-001"],
        "next_habit_id": "habit-stretch-001",
        "delay_minutes": 5,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 5
        }
      },
      {
        "id": "chain-morning-004",
        "trigger_habits": ["habit-stretch-001"],
        "next_habit_id": "habit-breakfast-001",
        "delay_minutes": 5,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 5
        }
      },
      {
        "id": "chain-morning-005",
        "trigger_habits": ["habit-breakfast-001"],
        "next_habit_id": "habit-sendoff-001",
        "delay_minutes": 10,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 10
        }
      },
      {
        "id": "chain-morning-006",
        "trigger_habits": ["habit-sendoff-001"],
        "next_habit_id": "habit-my-breakfast-001",
        "delay_minutes": 5,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 5
        }
      },
      {
        "id": "chain-morning-007",
        "trigger_habits": ["habit-my-breakfast-001"],
        "next_habit_id": "habit-work-start-001",
        "delay_minutes": 30,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 30
        }
      },
      {
        "id": "chain-night-001",
        "trigger_habits": ["habit-child-sleep-001"],
        "next_habit_id": "habit-night-sleep-001",
        "delay_minutes": 30,
        "trigger_condition": {
          "type": "timeAfter",
          "delayMinutes": 30
        }
      }
    ]
  }
}
```

---

## 3. コア機能実装

### 3.1 NLP（自然言語処理）

**目的**：ユーザー入力から習慣・タスクを抽出

```python
class NLPAnalyzer:
    """
    ユーザーの自由記述テキストから習慣IDを抽出
    """
    
    def extract_habits(self, user_input: str, habits: List[Habit]) -> List[ExtractedHabit]:
        """
        入力テキストから関連習慣を抽出
        
        Args:
            user_input: ユーザーの入力テキスト
            habits: 定義済みの習慣リスト
        
        Returns:
            ExtractedHabit のリスト
        """
        # 実装例：
        # 1. テキストを形態素解析
        # 2. 各習慣の name/description とマッチング
        # 3. 信頼度スコア付きで返す
        pass
    
    def detect_task_type(self, user_input: str) -> TaskType:
        """
        入力が「習慣」か「単発タスク」かを判定
        
        判定基準：
        - 「毎日」「毎週」などの頻度表現 → 習慣
        - 「今日は」「今」などの一度限りの表現 → タスク
        - イベント名など固有の単発表現 → タスク
        """
        pass
    
    def detect_parallel_execution(self, user_input: str) -> bool:
        """
        複数のタスク・習慣が並行実行されているかを判定
        
        判定基準：
        - 「～しながら」「～と一緒に」 → 並行実行
        """
        pass
```

**実装選択肢**：
- A: Claude API を使用（推奨 - 精度が高い）
- B: spaCy/Janome（軽量、オンプレミス可能）
- C: 正規表現 + 辞書マッチング（単純だが拡張性低い）

### 3.2 ExecutionInference（実行推測）

```python
class ExecutionInferenceEngine:
    """
    ユーザーの報告から、実際の習慣実行を推測・判定
    """
    
    def generate_inference(
        self,
        user_input: str,
        extracted_habits: List[ExtractedHabit],
        habit_definitions: List[Habit],
        chains: List[HabitChain]
    ) -> ExecutionInference:
        """
        ExecutionInference オブジェクトを生成
        """
        
        # 1. 各習慣の executionType を判定
        for habit in extracted_habits:
            execution_type = self.determine_execution_type(
                habit, user_input, habit_definitions
            )
            completion_percentage = self.calculate_completion_percentage(
                habit, execution_type, habit_definitions
            )
        
        # 2. チェーン整合性をチェック
        chain_consistency = self.check_chain_consistency(
            extracted_habits, chains
        )
        
        # 3. プロアクティブな質問を生成
        proactive_questions = self.generate_proactive_questions(
            chain_consistency
        )
        
        # 4. Onboarding キュー更新の必要性を判定
        queue_updates = self.determine_queue_updates(
            user_input, extracted_habits, habit_definitions
        )
        
        return ExecutionInference(
            inferred_habits=inferred_habits,
            chain_consistency_check=chain_consistency,
            proactive_questions=proactive_questions,
            queue_updates=queue_updates
        )
    
    def determine_execution_type(
        self,
        habit: ExtractedHabit,
        user_input: str,
        habit_definitions: List[Habit]
    ) -> ExecutionType:
        """
        executionType を判定（direct / partial / inferred）
        """
        # direct: ユーザーが明示的に「やった」と言っている
        # partial: 部分的に完了した、または不確定
        # inferred: 文脈から推測
        pass
    
    def check_chain_consistency(
        self,
        extracted_habits: List[ExtractedHabit],
        chains: List[HabitChain]
    ) -> ChainConsistencyCheck:
        """
        期待される習慣チェーンと、実際の報告内容を比較
        
        Returns:
            - detectedChain: 実際に報告された順序
            - expectedChain: 定義に基づく期待される順序
            - skippedSteps: スキップされた習慣
            - unreportedSteps: 未報告の習慣
            - inconsistencyLevel: 不整合の程度（0-1）
        """
        pass
    
    def generate_proactive_questions(
        self,
        chain_consistency: ChainConsistencyCheck
    ) -> List[str]:
        """
        チェーン整合性に基づいて、ユーザーに問う質問を生成
        """
        # skippedSteps や unreportedSteps に基づいて質問を生成
        pass
```

### 3.3 AI応答生成

```python
class ResponseGenerator:
    """
    ユーザーへの AI 応答を生成
    """
    
    def generate_response(
        self,
        user_input: str,
        inference: ExecutionInference,
        habits: List[Habit]
    ) -> str:
        """
        シンプルで簡潔な応答を生成
        
        構成：
        1. 報告内容の確認メッセージ
        2. プロアクティブな質問（あれば）
        3. モチベーションの言葉（オプション）
        """
        
        # 例：
        # 「朝食を準備されたんですね。素晴らしい。
        #  洗顔はしましたか？またストレッチはしましたか？」
        pass
```

### 3.4 データ記録

```python
class DataRecorder:
    """
    ユーザー入力と AI 推測結果をDB に記録
    """
    
    def save_message(self, user_id: str, conversation_id: str, content: str) -> Message:
        """Message を保存"""
        pass
    
    def save_habit_execution(
        self,
        user_id: str,
        message_id: str,
        inference: ExecutionInference
    ) -> List[HabitExecution]:
        """HabitExecution を保存"""
        pass
    
    def save_task(
        self,
        user_id: str,
        message_id: str,
        task_info: dict
    ) -> Task:
        """Task を保存"""
        pass
    
    def save_execution_inference(
        self,
        user_id: str,
        message_id: str,
        inference: ExecutionInference
    ) -> ExecutionInference:
        """ExecutionInference を保存"""
        pass
    
    def update_onboarding_queue(
        self,
        user_id: str,
        new_questions: List[dict]
    ) -> None:
        """QueuedOnboardingQuestions を更新"""
        pass
```

---

## 4. API エンドポイント（実行モード用）

### 4.1 メッセージ送信

```
POST /api/v1/messages

Request:
{
  "conversation_id": "conv-001",
  "content": "9:30に起きました"
}

Response:
{
  "message_id": "msg-001",
  "ai_response": "おはようございます。朝7時起床とのことですね。素晴らしい。",
  "inferred_habits": [
    {
      "habit_id": "habit-wakeup-001",
      "habit_name": "朝7時起床",
      "execution_type": "direct",
      "completion_percentage": 100
    }
  ],
  "proactive_questions": [
    "朝食や身支度はされましたか？"
  ],
  "queued_onboarding_updates": [
    {
      "question": "土曜日は『朝7時起床』ではなく『9時30分起床』なのですね。...",
      "priority": "high"
    }
  ]
}
```

### 4.2 チェーン整合性チェック

```
GET /api/v1/habits/{habit_id}/expected-chain

Response:
{
  "habit_id": "habit-stretch-001",
  "expected_chain": [
    "朝7時起床",
    "洗顔・身だしなみ",
    "コーヒーボタンON",
    "ストレッチ（軽く）"
  ],
  "prerequisite_habits": [
    {
      "habit_id": "habit-move-table-001",
      "habit_name": "居間の机をどかす",
      "is_mandatory": true,
      "estimated_time_minutes": 1-2
    }
  ]
}
```

### 4.3 ユーザープロフィール取得

```
GET /api/v1/users/{user_id}/habits

Response:
{
  "user_id": "user-akira-001",
  "habits": [
    {
      "id": "habit-wakeup-001",
      "name": "朝7時起床",
      "description": "平日、7時～7時15分に起床する",
      "importance_inferred": 0.7,
      "hidden_parameters": {...}
    },
    ...
  ],
  "chains": [...]
}
```

---

## 5. 実装マイルストーン

### Phase 1: 基盤構築（Week 1-2）
- [ ] DB スキーマ作成
- [ ] モックデータ登録（Akira の習慣・チェーン）
- [ ] API フレームワーク構築（FastAPI / Express など）

### Phase 2: NLP と推測判定（Week 2-3）
- [ ] NLP エンジン実装（Claude API 統合）
- [ ] ExecutionInference エンジン実装
- [ ] チェーン整合性チェック実装

### Phase 3: メッセージ処理（Week 3-4）
- [ ] Message 保存 API
- [ ] HabitExecution/Task 記録
- [ ] AI 応答生成

### Phase 4: テスト・デバッグ（Week 4-5）
- [ ] ユニットテスト
- [ ] エンドツーエンドテスト
- [ ] モックデータでの動作確認

### Phase 5: フロントエンド基本（Week 5-6）
- [ ] チャット UI（シンプル版）
- [ ] メッセージ送受信
- [ ] 習慣一覧表示

---

## 6. 開発時の注意点

### 6.1 NLP の信頼度

- Claude API は精度が高いが、コストがかかる
- 初期実装では、簡単な キーワードマッチング + Claude API のハイブリッドを検討

### 6.2 チェーン整合性の判定

- 完璧さを求めず、7割程度の精度で十分
- ユーザーのフィードバックで段階的に改善

### 6.3 モックデータの管理

- JSON ファイルで管理しやすいが、複雑になったら DB に移行
- Akira のみのモックで開発開始し、他ユーザーは後日対応

### 6.4 エラーハンドリング

- NLP が習慣を抽出できない場合 → デフォルト応答
- DB 接続エラー → ユーザーに通知（再試行促す）

---

## 7. デバッグモード

実装中の動作確認用：

```python
# 環境変数で有効化
if DEBUG_MODE:
    response["debug_info"] = {
        "nlp_result": extracted_habits,
        "inference_details": inference.to_dict(),
        "chain_analysis": chain_consistency.to_dict(),
        "ai_reasoning": "..."
    }
```

---

## 8. 次フェーズへの検討項目

実行モードが安定したら、以下を実装：

- Onboarding モード（質問キュー処理、習慣再定義）
- レポートモード（統計分析、フィードバック）
- ユーザー管理・認証
- フロントエンド（iOS / Web）
- UI/UX 最適化

