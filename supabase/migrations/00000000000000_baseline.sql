--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--



--
-- Name: handle_vote(uuid, uuid, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_vote(p_post_id uuid, p_user_id uuid, p_vote smallint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  existing_vote smallint;
BEGIN
  -- Check if user already voted on this post
  SELECT vote INTO existing_vote
  FROM post_votes
  WHERE user_id = p_user_id AND post_id = p_post_id;

  IF NOT FOUND THEN
    -- No existing vote — insert and increment the right counter
    INSERT INTO post_votes (user_id, post_id, vote)
    VALUES (p_user_id, p_post_id, p_vote);

    IF p_vote = 1 THEN
      UPDATE published_tests SET upvotes = upvotes + 1 WHERE id = p_post_id;
    ELSE
      UPDATE published_tests SET downvotes = downvotes + 1 WHERE id = p_post_id;
    END IF;

  ELSIF existing_vote = p_vote THEN
    -- Same vote again — toggle off (delete and decrement)
    DELETE FROM post_votes
    WHERE user_id = p_user_id AND post_id = p_post_id;

    IF p_vote = 1 THEN
      UPDATE published_tests SET upvotes = GREATEST(upvotes - 1, 0) WHERE id = p_post_id;
    ELSE
      UPDATE published_tests SET downvotes = GREATEST(downvotes - 1, 0) WHERE id = p_post_id;
    END IF;

  ELSE
    -- Switched vote (upvote→downvote or vice versa)
    UPDATE post_votes SET vote = p_vote
    WHERE user_id = p_user_id AND post_id = p_post_id;

    IF p_vote = 1 THEN
      -- Switched from downvote to upvote
      UPDATE published_tests
        SET upvotes   = upvotes + 1,
            downvotes = GREATEST(downvotes - 1, 0)
        WHERE id = p_post_id;
    ELSE
      -- Switched from upvote to downvote
      UPDATE published_tests
        SET downvotes = downvotes + 1,
            upvotes   = GREATEST(upvotes - 1, 0)
        WHERE id = p_post_id;
    END IF;
  END IF;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_evaluations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_evaluations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_result_id uuid NOT NULL,
    user_id uuid NOT NULL,
    question_id uuid NOT NULL,
    answer_photo_url text,
    extracted_text text,
    model_answer_used text,
    score_awarded numeric(5,2),
    max_score numeric(5,2),
    feedback_json jsonb,
    evaluated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: campuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institution_id uuid NOT NULL,
    name text NOT NULL,
    short_name text NOT NULL,
    subdomain text,
    location text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: career_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.career_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    industry_relevance_text text,
    industry_relevance_score numeric,
    industry_relevance_updated_at timestamp with time zone,
    confirmed_at timestamp with time zone,
    paused_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT career_units_industry_relevance_score_check CHECK (((industry_relevance_score >= (0)::numeric) AND (industry_relevance_score <= (1)::numeric)))
);


--
-- Name: custom_subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_subjects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institution_id uuid NOT NULL,
    course_code text NOT NULL,
    name text NOT NULL,
    credits smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: institutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.institutions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    short_name text NOT NULL,
    email_patterns jsonb DEFAULT '[]'::jsonb NOT NULL,
    website text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: nova_capacity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nova_capacity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    capacity text NOT NULL,
    logged_for_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT nova_capacity_log_capacity_check CHECK ((capacity = ANY (ARRAY['light'::text, 'normal'::text, 'packed'::text])))
);


--
-- Name: nova_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nova_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_subject_id uuid,
    content text NOT NULL,
    confirmed_at timestamp with time zone,
    superseded_at timestamp with time zone,
    supersedes_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_votes (
    user_id uuid NOT NULL,
    post_id uuid NOT NULL,
    vote smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT post_votes_vote_check CHECK ((vote = ANY (ARRAY[1, '-1'::integer])))
);


--
-- Name: published_tests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.published_tests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    published_by uuid,
    college text NOT NULL,
    subject text NOT NULL,
    exam_type text NOT NULL,
    question_ids uuid[] NOT NULL,
    upvotes integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    subject_id uuid,
    campus_id uuid,
    downvotes integer DEFAULT 0 NOT NULL,
    CONSTRAINT published_tests_exam_type_check CHECK ((exam_type = ANY (ARRAY['quiz1'::text, 'midsem'::text, 'quiz2'::text, 'compre'::text, 'generated'::text])))
);


--
-- Name: question_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.question_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    attempt_id uuid NOT NULL,
    question_id uuid NOT NULL,
    topic text,
    is_correct boolean,
    marks_available integer DEFAULT 0 NOT NULL,
    marks_obtained numeric(5,2) DEFAULT 0 NOT NULL,
    self_rating smallint,
    ai_evaluation_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    error_category text,
    topic_id uuid,
    CONSTRAINT question_results_error_category_check CHECK ((error_category = ANY (ARRAY['concept_gap'::text, 'practice_gap'::text, 'careless'::text]))),
    CONSTRAINT question_results_self_rating_check CHECK (((self_rating >= 1) AND (self_rating <= 5)))
);


--
-- Name: questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    question_text text NOT NULL,
    marks integer DEFAULT 0 NOT NULL,
    question_type text NOT NULL,
    subject text NOT NULL,
    college text NOT NULL,
    paper_year integer,
    academic_year smallint,
    exam_type text,
    embedding public.vector(384),
    published boolean DEFAULT false NOT NULL,
    published_by uuid,
    published_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    options jsonb,
    correct_index smallint,
    subject_id uuid,
    campus_id uuid,
    source_pdf_id uuid,
    doc_type text,
    topic text,
    has_diagram boolean DEFAULT false NOT NULL,
    sub_parts jsonb,
    model_answer text,
    answer_source text,
    confidence_score numeric(4,3),
    marks_inferred boolean DEFAULT false NOT NULL,
    topic_id uuid,
    CONSTRAINT questions_academic_year_check CHECK (((academic_year >= 1) AND (academic_year <= 4))),
    CONSTRAINT questions_exam_type_check CHECK ((exam_type = ANY (ARRAY['quiz1'::text, 'midsem'::text, 'quiz2'::text, 'compre'::text, 'generated'::text]))),
    CONSTRAINT questions_question_type_check CHECK ((question_type = ANY (ARRAY['mcq'::text, 'short_answer'::text, 'long_answer'::text, 'numerical'::text])))
);


--
-- Name: situation_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.situation_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_subject_id uuid,
    flag_text text NOT NULL,
    confirmed_at timestamp with time zone,
    superseded_at timestamp with time zone,
    supersedes_id uuid,
    starts_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT situation_flags_expiry_check CHECK (((expires_at IS NULL) OR (expires_at > starts_at)))
);


--
-- Name: staleness_tracker; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staleness_tracker (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_subject_id uuid,
    career_unit_id uuid,
    last_meaningfully_touched timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    topic_id uuid,
    CONSTRAINT staleness_tracker_unit_check CHECK ((((user_subject_id IS NOT NULL) AND (career_unit_id IS NULL)) OR ((user_subject_id IS NULL) AND (career_unit_id IS NOT NULL))))
);


--
-- Name: standing_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.standing_flags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    user_subject_id uuid,
    instruction_text text NOT NULL,
    confirmed_at timestamp with time zone,
    superseded_at timestamp with time zone,
    supersedes_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: study_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.study_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_subject_id uuid NOT NULL,
    user_id uuid NOT NULL,
    subject_name text NOT NULL,
    handout_url text NOT NULL,
    topics jsonb NOT NULL,
    weekly_plan jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    raw_handout_data jsonb
);


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subjects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    institution_id uuid NOT NULL,
    name text NOT NULL,
    short_name text,
    academic_year smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    semester smallint,
    credits smallint,
    campus_id uuid,
    CONSTRAINT subjects_academic_year_check CHECK (((academic_year >= 1) AND (academic_year <= 4)))
);


--
-- Name: test_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    test_id uuid NOT NULL,
    user_id uuid NOT NULL,
    subject_id uuid,
    attempt_number smallint DEFAULT 1 NOT NULL,
    total_marks integer DEFAULT 0 NOT NULL,
    obtained_marks integer DEFAULT 0 NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    exam_type text,
    CONSTRAINT test_attempts_exam_type_check CHECK ((exam_type = ANY (ARRAY['quiz1'::text, 'midsem'::text, 'quiz2'::text, 'compre'::text])))
);


--
-- Name: topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    subject_id uuid,
    custom_subject_id uuid,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT topics_subject_check CHECK ((((subject_id IS NOT NULL) AND (custom_subject_id IS NULL)) OR ((subject_id IS NULL) AND (custom_subject_id IS NOT NULL))))
);


--
-- Name: uploaded_pdfs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploaded_pdfs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    uploaded_by uuid,
    uploaded_as text DEFAULT 'student'::text NOT NULL,
    storage_path text NOT NULL,
    doc_type text NOT NULL,
    subject_id uuid,
    campus_id uuid,
    exam_type text,
    paper_year integer,
    topic text,
    status text DEFAULT 'pending'::text NOT NULL,
    questions_extracted integer DEFAULT 0 NOT NULL,
    questions_failed integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    topic_id uuid,
    CONSTRAINT uploaded_pdfs_doc_type_check CHECK ((doc_type = ANY (ARRAY['pyq'::text, 'tutorial'::text, 'solution'::text, 'lab'::text, 'misc'::text]))),
    CONSTRAINT uploaded_pdfs_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'partial'::text, 'failed'::text]))),
    CONSTRAINT uploaded_pdfs_uploaded_as_check CHECK ((uploaded_as = ANY (ARRAY['student'::text, 'admin'::text])))
);


--
-- Name: user_subject_exams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subject_exams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_subject_id uuid NOT NULL,
    exam_type text NOT NULL,
    exam_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_subject_exams_exam_type_check CHECK ((exam_type = ANY (ARRAY['quiz1'::text, 'midsem'::text, 'quiz2'::text, 'compre'::text])))
);


--
-- Name: user_subjects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_subjects (
    user_id uuid NOT NULL,
    subject_id uuid,
    semester text NOT NULL,
    handout_url text,
    handout_uploaded_at timestamp with time zone,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    handout_filename text,
    custom_subject_id uuid,
    CONSTRAINT user_subjects_subject_check CHECK ((((subject_id IS NOT NULL) AND (custom_subject_id IS NULL)) OR ((subject_id IS NULL) AND (custom_subject_id IS NOT NULL))))
);


--
-- Name: user_topic_weights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_topic_weights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    subject_id uuid,
    topic text NOT NULL,
    weight numeric(4,3) DEFAULT 0.500 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom_subject_id uuid,
    topic_id uuid,
    CONSTRAINT user_topic_weights_subject_check CHECK ((((subject_id IS NOT NULL) AND (custom_subject_id IS NULL)) OR ((subject_id IS NULL) AND (custom_subject_id IS NOT NULL)))),
    CONSTRAINT user_topic_weights_weight_check CHECK (((weight >= (0)::numeric) AND (weight <= (1)::numeric)))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    roll_number text,
    college text,
    institution_id uuid,
    campus_id uuid,
    academic_year smallint,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    branch text,
    plan text DEFAULT 'free'::text NOT NULL,
    role text DEFAULT 'student'::text NOT NULL,
    semester_credits smallint,
    CONSTRAINT users_academic_year_check CHECK (((academic_year >= 1) AND (academic_year <= 4))),
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['student'::text, 'admin'::text, 'super_admin'::text])))
);


--
-- Name: ai_evaluations ai_evaluations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_evaluations
    ADD CONSTRAINT ai_evaluations_pkey PRIMARY KEY (id);


--
-- Name: campuses campuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campuses
    ADD CONSTRAINT campuses_pkey PRIMARY KEY (id);


--
-- Name: campuses campuses_short_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campuses
    ADD CONSTRAINT campuses_short_name_key UNIQUE (short_name);


--
-- Name: career_units career_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.career_units
    ADD CONSTRAINT career_units_pkey PRIMARY KEY (id);


--
-- Name: custom_subjects custom_subjects_institution_id_course_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_subjects
    ADD CONSTRAINT custom_subjects_institution_id_course_code_key UNIQUE (institution_id, course_code);


--
-- Name: custom_subjects custom_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_subjects
    ADD CONSTRAINT custom_subjects_pkey PRIMARY KEY (id);


--
-- Name: institutions institutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institutions
    ADD CONSTRAINT institutions_pkey PRIMARY KEY (id);


--
-- Name: institutions institutions_short_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.institutions
    ADD CONSTRAINT institutions_short_name_key UNIQUE (short_name);


--
-- Name: nova_capacity_log nova_capacity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_capacity_log
    ADD CONSTRAINT nova_capacity_log_pkey PRIMARY KEY (id);


--
-- Name: nova_capacity_log nova_capacity_log_unique_per_day; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_capacity_log
    ADD CONSTRAINT nova_capacity_log_unique_per_day UNIQUE (user_id, logged_for_date);


--
-- Name: nova_history nova_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_history
    ADD CONSTRAINT nova_history_pkey PRIMARY KEY (id);


--
-- Name: post_votes post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (user_id, post_id);


--
-- Name: published_tests published_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.published_tests
    ADD CONSTRAINT published_tests_pkey PRIMARY KEY (id);


--
-- Name: question_results question_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question_results
    ADD CONSTRAINT question_results_pkey PRIMARY KEY (id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (id);


--
-- Name: situation_flags situation_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.situation_flags
    ADD CONSTRAINT situation_flags_pkey PRIMARY KEY (id);


--
-- Name: staleness_tracker staleness_tracker_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staleness_tracker
    ADD CONSTRAINT staleness_tracker_pkey PRIMARY KEY (id);


--
-- Name: standing_flags standing_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standing_flags
    ADD CONSTRAINT standing_flags_pkey PRIMARY KEY (id);


--
-- Name: study_plans study_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_plans
    ADD CONSTRAINT study_plans_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_institution_name_year_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_institution_name_year_unique UNIQUE (institution_id, name, academic_year);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: test_attempts test_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_pkey PRIMARY KEY (id);


--
-- Name: test_attempts test_attempts_unique_attempt; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_unique_attempt UNIQUE (test_id, user_id, attempt_number);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: topics topics_unique_per_custom_subject; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_unique_per_custom_subject UNIQUE (custom_subject_id, name);


--
-- Name: topics topics_unique_per_subject; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_unique_per_subject UNIQUE (subject_id, name);


--
-- Name: uploaded_pdfs uploaded_pdfs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_pdfs
    ADD CONSTRAINT uploaded_pdfs_pkey PRIMARY KEY (id);


--
-- Name: user_subject_exams user_subject_exams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_exams
    ADD CONSTRAINT user_subject_exams_pkey PRIMARY KEY (id);


--
-- Name: user_subject_exams user_subject_exams_user_subject_id_exam_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_exams
    ADD CONSTRAINT user_subject_exams_user_subject_id_exam_type_key UNIQUE (user_subject_id, exam_type);


--
-- Name: user_subjects user_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subjects
    ADD CONSTRAINT user_subjects_pkey PRIMARY KEY (id);


--
-- Name: user_topic_weights user_topic_weights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_pkey PRIMARY KEY (id);


--
-- Name: user_topic_weights user_topic_weights_user_id_subject_id_topic_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_user_id_subject_id_topic_key UNIQUE (user_id, subject_id, topic);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_campuses_subdomain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campuses_subdomain ON public.campuses USING btree (subdomain);


--
-- Name: idx_published_tests_college; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_published_tests_college ON public.published_tests USING btree (college, created_at DESC);


--
-- Name: idx_questions_academic_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_academic_year ON public.questions USING btree (college, academic_year);


--
-- Name: idx_questions_college_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_college_subject ON public.questions USING btree (college, subject);


--
-- Name: idx_questions_college_subject_exam; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_college_subject_exam ON public.questions USING btree (college, subject, exam_type);


--
-- Name: idx_questions_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_embedding ON public.questions USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_questions_paper_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_paper_year ON public.questions USING btree (paper_year);


--
-- Name: idx_questions_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_questions_published ON public.questions USING btree (published) WHERE (published = true);


--
-- Name: question_results_attempt_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX question_results_attempt_id_idx ON public.question_results USING btree (attempt_id);


--
-- Name: question_results_question_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX question_results_question_id_idx ON public.question_results USING btree (question_id);


--
-- Name: study_plans_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX study_plans_active_idx ON public.study_plans USING btree (user_subject_id) WHERE (is_active = true);


--
-- Name: test_attempts_subject_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_attempts_subject_id_idx ON public.test_attempts USING btree (subject_id);


--
-- Name: test_attempts_test_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_attempts_test_id_idx ON public.test_attempts USING btree (test_id);


--
-- Name: test_attempts_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX test_attempts_user_id_idx ON public.test_attempts USING btree (user_id);


--
-- Name: topics_name_custom_subject_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX topics_name_custom_subject_ci ON public.topics USING btree (custom_subject_id, lower(name)) WHERE (custom_subject_id IS NOT NULL);


--
-- Name: topics_name_subject_ci; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX topics_name_subject_ci ON public.topics USING btree (subject_id, lower(name)) WHERE (subject_id IS NOT NULL);


--
-- Name: user_subjects_user_subject_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_subjects_user_subject_uidx ON public.user_subjects USING btree (user_id, subject_id) WHERE (subject_id IS NOT NULL);


--
-- Name: user_topic_weights_user_subject_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_topic_weights_user_subject_idx ON public.user_topic_weights USING btree (user_id, subject_id);


--
-- Name: user_topic_weights topic_weights_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER topic_weights_set_updated_at BEFORE UPDATE ON public.user_topic_weights FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users users_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ai_evaluations ai_evaluations_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_evaluations
    ADD CONSTRAINT ai_evaluations_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: ai_evaluations ai_evaluations_question_result_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_evaluations
    ADD CONSTRAINT ai_evaluations_question_result_id_fkey FOREIGN KEY (question_result_id) REFERENCES public.question_results(id) ON DELETE CASCADE;


--
-- Name: ai_evaluations ai_evaluations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_evaluations
    ADD CONSTRAINT ai_evaluations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: campuses campuses_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campuses
    ADD CONSTRAINT campuses_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: career_units career_units_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.career_units
    ADD CONSTRAINT career_units_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: custom_subjects custom_subjects_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_subjects
    ADD CONSTRAINT custom_subjects_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: nova_capacity_log nova_capacity_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_capacity_log
    ADD CONSTRAINT nova_capacity_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: nova_history nova_history_supersedes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_history
    ADD CONSTRAINT nova_history_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES public.nova_history(id);


--
-- Name: nova_history nova_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_history
    ADD CONSTRAINT nova_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: nova_history nova_history_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nova_history
    ADD CONSTRAINT nova_history_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id);


--
-- Name: post_votes post_votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.published_tests(id) ON DELETE CASCADE;


--
-- Name: post_votes post_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: published_tests published_tests_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.published_tests
    ADD CONSTRAINT published_tests_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: question_results question_results_ai_eval_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question_results
    ADD CONSTRAINT question_results_ai_eval_fk FOREIGN KEY (ai_evaluation_id) REFERENCES public.ai_evaluations(id) ON DELETE SET NULL;


--
-- Name: question_results question_results_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question_results
    ADD CONSTRAINT question_results_attempt_id_fkey FOREIGN KEY (attempt_id) REFERENCES public.test_attempts(id) ON DELETE CASCADE;


--
-- Name: question_results question_results_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question_results
    ADD CONSTRAINT question_results_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(id);


--
-- Name: question_results question_results_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question_results
    ADD CONSTRAINT question_results_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: questions questions_campus_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_campus_id_fk FOREIGN KEY (campus_id) REFERENCES public.campuses(id);


--
-- Name: questions questions_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: questions questions_source_pdf_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_source_pdf_fk FOREIGN KEY (source_pdf_id) REFERENCES public.uploaded_pdfs(id);


--
-- Name: questions questions_subject_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_subject_id_fk FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: questions questions_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: situation_flags situation_flags_supersedes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.situation_flags
    ADD CONSTRAINT situation_flags_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES public.situation_flags(id);


--
-- Name: situation_flags situation_flags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.situation_flags
    ADD CONSTRAINT situation_flags_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: situation_flags situation_flags_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.situation_flags
    ADD CONSTRAINT situation_flags_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id);


--
-- Name: staleness_tracker staleness_tracker_career_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staleness_tracker
    ADD CONSTRAINT staleness_tracker_career_unit_id_fkey FOREIGN KEY (career_unit_id) REFERENCES public.career_units(id);


--
-- Name: staleness_tracker staleness_tracker_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staleness_tracker
    ADD CONSTRAINT staleness_tracker_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: staleness_tracker staleness_tracker_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staleness_tracker
    ADD CONSTRAINT staleness_tracker_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: staleness_tracker staleness_tracker_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staleness_tracker
    ADD CONSTRAINT staleness_tracker_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id);


--
-- Name: standing_flags standing_flags_supersedes_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standing_flags
    ADD CONSTRAINT standing_flags_supersedes_id_fkey FOREIGN KEY (supersedes_id) REFERENCES public.standing_flags(id);


--
-- Name: standing_flags standing_flags_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standing_flags
    ADD CONSTRAINT standing_flags_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: standing_flags standing_flags_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standing_flags
    ADD CONSTRAINT standing_flags_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id);


--
-- Name: study_plans study_plans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_plans
    ADD CONSTRAINT study_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: study_plans study_plans_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_plans
    ADD CONSTRAINT study_plans_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id) ON DELETE CASCADE;


--
-- Name: subjects subjects_campus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES public.campuses(id);


--
-- Name: subjects subjects_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: test_attempts test_attempts_test_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_test_id_fkey FOREIGN KEY (test_id) REFERENCES public.published_tests(id) ON DELETE CASCADE;


--
-- Name: test_attempts test_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_attempts
    ADD CONSTRAINT test_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: topics topics_custom_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_custom_subject_id_fkey FOREIGN KEY (custom_subject_id) REFERENCES public.custom_subjects(id);


--
-- Name: topics topics_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: uploaded_pdfs uploaded_pdfs_campus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_pdfs
    ADD CONSTRAINT uploaded_pdfs_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES public.campuses(id);


--
-- Name: uploaded_pdfs uploaded_pdfs_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_pdfs
    ADD CONSTRAINT uploaded_pdfs_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: uploaded_pdfs uploaded_pdfs_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_pdfs
    ADD CONSTRAINT uploaded_pdfs_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: uploaded_pdfs uploaded_pdfs_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_pdfs
    ADD CONSTRAINT uploaded_pdfs_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: user_subject_exams user_subject_exams_user_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subject_exams
    ADD CONSTRAINT user_subject_exams_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id) ON DELETE CASCADE;


--
-- Name: user_subjects user_subjects_custom_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subjects
    ADD CONSTRAINT user_subjects_custom_subject_id_fkey FOREIGN KEY (custom_subject_id) REFERENCES public.custom_subjects(id) ON DELETE SET NULL;


--
-- Name: user_subjects user_subjects_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subjects
    ADD CONSTRAINT user_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE;


--
-- Name: user_subjects user_subjects_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_subjects
    ADD CONSTRAINT user_subjects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_topic_weights user_topic_weights_custom_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_custom_subject_id_fkey FOREIGN KEY (custom_subject_id) REFERENCES public.custom_subjects(id);


--
-- Name: user_topic_weights user_topic_weights_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE;


--
-- Name: user_topic_weights user_topic_weights_topic_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_topic_id_fkey FOREIGN KEY (topic_id) REFERENCES public.topics(id);


--
-- Name: user_topic_weights user_topic_weights_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_topic_weights
    ADD CONSTRAINT user_topic_weights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_campus_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_campus_id_fkey FOREIGN KEY (campus_id) REFERENCES public.campuses(id) ON DELETE SET NULL;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: users users_institution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES public.institutions(id) ON DELETE SET NULL;


--
-- Name: users Users can insert own row; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own row" ON public.users FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: users Users can read own row; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can read own row" ON public.users FOR SELECT USING ((auth.uid() = id));


--
-- Name: users Users can update own row; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own row" ON public.users FOR UPDATE USING ((auth.uid() = id));


--
-- Name: ai_evaluations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_evaluations ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_evaluations ai_evaluations_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_evaluations_own ON public.ai_evaluations USING ((auth.uid() = user_id));


--
-- Name: campuses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.campuses ENABLE ROW LEVEL SECURITY;

--
-- Name: campuses campuses_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY campuses_read_all ON public.campuses FOR SELECT USING (true);


--
-- Name: career_units; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.career_units ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_subjects custom_subjects_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custom_subjects_insert_auth ON public.custom_subjects FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: custom_subjects custom_subjects_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY custom_subjects_read_all ON public.custom_subjects FOR SELECT TO authenticated USING (true);


--
-- Name: published_tests dev read all published_tests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dev read all published_tests" ON public.published_tests FOR SELECT USING (true);


--
-- Name: questions dev read all questions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "dev read all questions" ON public.questions FOR SELECT USING (true);


--
-- Name: institutions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.institutions ENABLE ROW LEVEL SECURITY;

--
-- Name: institutions institutions_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY institutions_read_all ON public.institutions FOR SELECT USING (true);


--
-- Name: nova_capacity_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nova_capacity_log ENABLE ROW LEVEL SECURITY;

--
-- Name: nova_history; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nova_history ENABLE ROW LEVEL SECURITY;

--
-- Name: nova_capacity_log own_capacity_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_capacity_only ON public.nova_capacity_log USING ((user_id = auth.uid()));


--
-- Name: career_units own_career_units_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_career_units_only ON public.career_units USING ((user_id = auth.uid()));


--
-- Name: user_subject_exams own_exam_dates_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_exam_dates_only ON public.user_subject_exams USING ((user_subject_id IN ( SELECT user_subjects.id
   FROM public.user_subjects
  WHERE (user_subjects.user_id = auth.uid()))));


--
-- Name: nova_history own_history_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_history_only ON public.nova_history USING ((user_id = auth.uid()));


--
-- Name: situation_flags own_situation_flags_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_situation_flags_only ON public.situation_flags USING ((user_id = auth.uid()));


--
-- Name: staleness_tracker own_staleness_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_staleness_only ON public.staleness_tracker USING ((user_id = auth.uid()));


--
-- Name: standing_flags own_standing_flags_only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY own_standing_flags_only ON public.standing_flags USING ((user_id = auth.uid()));


--
-- Name: uploaded_pdfs pdfs_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pdfs_insert_own ON public.uploaded_pdfs FOR INSERT WITH CHECK ((auth.uid() = uploaded_by));


--
-- Name: uploaded_pdfs pdfs_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pdfs_read_all ON public.uploaded_pdfs FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: post_votes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: published_tests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.published_tests ENABLE ROW LEVEL SECURITY;

--
-- Name: question_results; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.question_results ENABLE ROW LEVEL SECURITY;

--
-- Name: question_results question_results_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY question_results_own ON public.question_results USING ((auth.uid() = ( SELECT test_attempts.user_id
   FROM public.test_attempts
  WHERE (test_attempts.id = question_results.attempt_id))));


--
-- Name: questions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

--
-- Name: questions questions_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY questions_read_all ON public.questions FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: questions questions_write_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY questions_write_admin ON public.questions USING ((auth.uid() IN ( SELECT users.id
   FROM public.users
  WHERE (users.role = ANY (ARRAY['admin'::text, 'super_admin'::text])))));


--
-- Name: situation_flags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.situation_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: staleness_tracker; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.staleness_tracker ENABLE ROW LEVEL SECURITY;

--
-- Name: standing_flags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.standing_flags ENABLE ROW LEVEL SECURITY;

--
-- Name: published_tests students insert own published tests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "students insert own published tests" ON public.published_tests FOR INSERT WITH CHECK ((published_by = auth.uid()));


--
-- Name: published_tests students read own campus published tests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "students read own campus published tests" ON public.published_tests FOR SELECT USING ((college = ( SELECT u.college
   FROM public.users u
  WHERE (u.id = auth.uid()))));


--
-- Name: study_plans; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.study_plans ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: subjects subjects_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subjects_insert_auth ON public.subjects FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: subjects subjects_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subjects_read_all ON public.subjects FOR SELECT USING (true);


--
-- Name: test_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: test_attempts test_attempts_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY test_attempts_own ON public.test_attempts USING ((auth.uid() = user_id));


--
-- Name: published_tests tests_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tests_insert_own ON public.published_tests FOR INSERT WITH CHECK ((auth.uid() = published_by));


--
-- Name: published_tests tests_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tests_read_all ON public.published_tests FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: user_topic_weights topic_weights_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY topic_weights_own ON public.user_topic_weights USING ((auth.uid() = user_id));


--
-- Name: uploaded_pdfs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.uploaded_pdfs ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subject_exams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_subject_exams ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subjects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_subjects ENABLE ROW LEVEL SECURITY;

--
-- Name: user_subjects user_subjects_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_subjects_own ON public.user_subjects USING ((auth.uid() = user_id));


--
-- Name: user_topic_weights; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_topic_weights ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: post_votes users can delete own votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users can delete own votes" ON public.post_votes FOR DELETE USING ((user_id = auth.uid()));


--
-- Name: post_votes users can insert own votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users can insert own votes" ON public.post_votes FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: post_votes users can read own votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users can read own votes" ON public.post_votes FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: post_votes users can update own votes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users can update own votes" ON public.post_votes FOR UPDATE USING ((user_id = auth.uid()));


--
-- Name: study_plans users manage own plans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users manage own plans" ON public.study_plans USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: users users read own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users read own profile" ON public.users FOR SELECT USING ((id = auth.uid()));


--
-- Name: users users update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "users update own profile" ON public.users FOR UPDATE USING ((id = auth.uid()));


--
-- Name: users users_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert_own ON public.users FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: users users_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_own ON public.users FOR SELECT USING ((auth.uid() = id));


--
-- Name: users users_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_own ON public.users FOR UPDATE USING ((auth.uid() = id));


--
-- PostgreSQL database dump complete
--


