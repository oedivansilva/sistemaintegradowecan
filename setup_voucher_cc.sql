-- ══════════════════════════════════════════════════════════════
--  WECANBR · setup_voucher_cc.sql
--  Execute no SQL Editor do Supabase.
--  1. Ajusta trigger de fila_voucher para detectar VOUCHER
--  2. Cria tabela centro_custos + RPCs
--  3. Cria tabela voucher_usuarios + RPCs de gestão
--  OBS: voucher_colaboradores já existe do setup_v2.sql
-- ══════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════
--  1. CORRIGIR TRIGGER DA FILA DE VOUCHER
--  Só entra na fila se "transporte" contém VOUCHER
--  (não mais MOBILIDADE isolado)
-- ════════════════════════════════════════════

-- Função que detecta se o transporte deve ir para fila
CREATE OR REPLACE FUNCTION _wc_transporte_tem_voucher(p_transporte text)
RETURNS boolean AS $$
BEGIN
  RETURN upper(coalesce(p_transporte,'')) LIKE '%VOUCHER%';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Recriar a função wc_salvar_vaga para usar a nova detecção
CREATE OR REPLACE FUNCTION wc_salvar_vaga(p_token text, p_vaga jsonb, p_jira_original text)
RETURNS json AS $$
DECLARE
  s          sessoes%ROWTYPE;
  v_jira     text;
  v_transp   text;
  v_colab    text;
  v_consultor text;
  tem_voucher boolean;
  era_voucher boolean;
  criado      boolean := false;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;

  v_jira      := trim(p_vaga->>'jira');
  v_transp    := p_vaga->>'transporte';
  v_colab     := p_vaga->>'colaborador';
  v_consultor := p_vaga->>'consultor';

  IF v_jira IS NULL OR v_jira = '' THEN
    RETURN json_build_object('ok',false,'erro','Código Jira é obrigatório.');
  END IF;

  tem_voucher := _wc_transporte_tem_voucher(v_transp);

  -- Verificar se já existia e se já era voucher
  SELECT _wc_transporte_tem_voucher(v.transporte) INTO era_voucher
  FROM vagas v WHERE v.jira = p_jira_original;

  IF NOT FOUND THEN
    -- INSERT nova vaga
    INSERT INTO vagas (
      jira, consultor, codigo_hub, regional, recebimento, mes, local_trabalho,
      modalidade, tempo, cargo, turno, horario, escala, preferencia, colaborador,
      status_uniforme, matricula, ops_id, data_adm_solicitada, data_reprog,
      nova_data_eto, data_adm_realizada, etapa, status_vaga, tipo_vaga, salario,
      cnpj, departamento_gi, transporte, refeicao, cesta_basica, gestor_turno,
      contato_gestor_turno, unidade_wecan, cpf, email_colaborador, telefone,
      indicacao, genero, tipo_processo, colete, bota, luva, no_show,
      motivo_atraso, observacao, tipo_processo_desistente, aba
    ) VALUES (
      v_jira,
      p_vaga->>'consultor', p_vaga->>'codigo_hub', p_vaga->>'regional',
      NULLIF(p_vaga->>'recebimento','')::date, NULLIF(p_vaga->>'mes','')::date,
      p_vaga->>'local_trabalho', p_vaga->>'modalidade', p_vaga->>'tempo',
      p_vaga->>'cargo', p_vaga->>'turno', p_vaga->>'horario', p_vaga->>'escala',
      p_vaga->>'preferencia', v_colab, p_vaga->>'status_uniforme',
      p_vaga->>'matricula', p_vaga->>'ops_id',
      NULLIF(p_vaga->>'data_adm_solicitada','')::date,
      NULLIF(p_vaga->>'data_reprog','')::date,
      NULLIF(p_vaga->>'nova_data_eto','')::date,
      NULLIF(p_vaga->>'data_adm_realizada','')::date,
      p_vaga->>'etapa', p_vaga->>'status_vaga', p_vaga->>'tipo_vaga',
      p_vaga->>'salario', p_vaga->>'cnpj', p_vaga->>'departamento_gi',
      v_transp, p_vaga->>'refeicao', p_vaga->>'cesta_basica',
      p_vaga->>'gestor_turno', p_vaga->>'contato_gestor_turno',
      p_vaga->>'unidade_wecan', p_vaga->>'cpf', p_vaga->>'email_colaborador',
      p_vaga->>'telefone', p_vaga->>'indicacao', p_vaga->>'genero',
      p_vaga->>'tipo_processo', p_vaga->>'colete', p_vaga->>'bota',
      p_vaga->>'luva', p_vaga->>'no_show', p_vaga->>'motivo_atraso',
      p_vaga->>'observacao', p_vaga->>'tipo_processo_desistente',
      COALESCE(p_vaga->>'aba','HUBs')
    );
    criado := true;
  ELSE
    -- UPDATE vaga existente
    UPDATE vagas SET
      consultor=p_vaga->>'consultor', codigo_hub=p_vaga->>'codigo_hub',
      regional=p_vaga->>'regional',
      recebimento=NULLIF(p_vaga->>'recebimento','')::date,
      mes=NULLIF(p_vaga->>'mes','')::date,
      local_trabalho=p_vaga->>'local_trabalho', modalidade=p_vaga->>'modalidade',
      tempo=p_vaga->>'tempo', cargo=p_vaga->>'cargo', turno=p_vaga->>'turno',
      horario=p_vaga->>'horario', escala=p_vaga->>'escala',
      preferencia=p_vaga->>'preferencia', colaborador=v_colab,
      status_uniforme=p_vaga->>'status_uniforme', matricula=p_vaga->>'matricula',
      ops_id=p_vaga->>'ops_id',
      data_adm_solicitada=NULLIF(p_vaga->>'data_adm_solicitada','')::date,
      data_reprog=NULLIF(p_vaga->>'data_reprog','')::date,
      nova_data_eto=NULLIF(p_vaga->>'nova_data_eto','')::date,
      data_adm_realizada=NULLIF(p_vaga->>'data_adm_realizada','')::date,
      etapa=p_vaga->>'etapa', status_vaga=p_vaga->>'status_vaga',
      tipo_vaga=p_vaga->>'tipo_vaga', salario=p_vaga->>'salario',
      cnpj=p_vaga->>'cnpj', departamento_gi=p_vaga->>'departamento_gi',
      transporte=v_transp, refeicao=p_vaga->>'refeicao',
      cesta_basica=p_vaga->>'cesta_basica', gestor_turno=p_vaga->>'gestor_turno',
      contato_gestor_turno=p_vaga->>'contato_gestor_turno',
      unidade_wecan=p_vaga->>'unidade_wecan', cpf=p_vaga->>'cpf',
      email_colaborador=p_vaga->>'email_colaborador', telefone=p_vaga->>'telefone',
      indicacao=p_vaga->>'indicacao', genero=p_vaga->>'genero',
      tipo_processo=p_vaga->>'tipo_processo', colete=p_vaga->>'colete',
      bota=p_vaga->>'bota', luva=p_vaga->>'luva', no_show=p_vaga->>'no_show',
      motivo_atraso=p_vaga->>'motivo_atraso', observacao=p_vaga->>'observacao',
      tipo_processo_desistente=p_vaga->>'tipo_processo_desistente'
    WHERE jira = p_jira_original;

    -- Se jira mudou, atualizar chave
    IF v_jira <> p_jira_original THEN
      UPDATE vagas SET jira = v_jira WHERE jira = p_jira_original;
    END IF;
  END IF;

  -- Gerenciar fila de voucher
  IF tem_voucher AND v_colab IS NOT NULL AND v_colab <> '' THEN
    INSERT INTO fila_voucher(vaga_jira, colaborador, transporte, status, consultor)
    VALUES(v_jira, v_colab, v_transp, 'pendente', v_consultor)
    ON CONFLICT(vaga_jira) DO UPDATE
      SET colaborador=EXCLUDED.colaborador,
          transporte=EXCLUDED.transporte,
          consultor=EXCLUDED.consultor,
          status=CASE WHEN fila_voucher.status='rejeitado' THEN 'pendente' ELSE fila_voucher.status END;
  ELSIF NOT tem_voucher AND era_voucher THEN
    -- Removeu o voucher: retira da fila
    DELETE FROM fila_voucher WHERE vaga_jira = v_jira;
  END IF;

  RETURN json_build_object('ok',true,'criado',criado);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_salvar_vaga(text,jsonb,text) TO anon;

-- ════════════════════════════════════════════
--  2. VOUCHER — GESTÃO DE USUÁRIOS
--  tabela voucher_usuarios já existe (setup_v2.sql)
--  Apenas garantir que existe
-- ════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS voucher_usuarios (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  nome        text NOT NULL,
  email       text UNIQUE NOT NULL,
  senha_hash  text NOT NULL,
  salt        text NOT NULL,
  perfil      text NOT NULL DEFAULT 'usuario',
  permissoes  jsonb DEFAULT '[]'::jsonb,
  ativo       boolean DEFAULT true,
  criado_por  text,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE voucher_usuarios DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE voucher_usuarios TO anon;

-- RPCs de gestão de usuários Voucher (recriar para garantir)
CREATE OR REPLACE FUNCTION wc_voucher_listar_usuarios(p_token text)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE; res json;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil <> 'master' THEN RETURN json_build_object('ok',false,'erro','Sem permissão.'); END IF;
  SELECT json_agg(json_build_object(
    'id',id,'nome',nome,'email',email,'perfil',perfil,'ativo',ativo,
    'permissoes',COALESCE(permissoes,'[]')
  ) ORDER BY nome) INTO res FROM voucher_usuarios;
  RETURN json_build_object('ok',true,'usuarios',COALESCE(res,'[]'::json));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_voucher_listar_usuarios(text) TO anon;

CREATE OR REPLACE FUNCTION wc_voucher_salvar_usuario(p_token text, p_usuario jsonb)
RETURNS json AS $$
DECLARE
  s sessoes%ROWTYPE; uid uuid; salt text; hash text;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil <> 'master' THEN RETURN json_build_object('ok',false,'erro','Sem permissão.'); END IF;
  uid := NULLIF(trim(p_usuario->>'id'),'')::uuid;
  IF uid IS NOT NULL THEN
    IF NULLIF(trim(p_usuario->>'senha'),'') IS NOT NULL THEN
      salt:=encode(gen_random_bytes(16),'hex');
      hash:=encode(digest(trim(p_usuario->>'senha')||'::'||salt||'::wecanbr','sha256'),'hex');
      UPDATE voucher_usuarios SET nome=trim(p_usuario->>'nome'),
        email=lower(trim(p_usuario->>'email')), perfil=p_usuario->>'perfil',
        permissoes=(p_usuario->>'permissoes')::jsonb,
        senha_hash=hash, salt=salt WHERE id=uid;
    ELSE
      UPDATE voucher_usuarios SET nome=trim(p_usuario->>'nome'),
        email=lower(trim(p_usuario->>'email')), perfil=p_usuario->>'perfil',
        permissoes=(p_usuario->>'permissoes')::jsonb WHERE id=uid;
    END IF;
  ELSE
    IF EXISTS(SELECT 1 FROM voucher_usuarios WHERE email=lower(trim(p_usuario->>'email'))) THEN
      RETURN json_build_object('ok',false,'erro','E-mail já cadastrado.');
    END IF;
    IF NULLIF(trim(p_usuario->>'senha'),'') IS NULL THEN
      RETURN json_build_object('ok',false,'erro','Defina uma senha.');
    END IF;
    salt:=encode(gen_random_bytes(16),'hex');
    hash:=encode(digest(trim(p_usuario->>'senha')||'::'||salt||'::wecanbr','sha256'),'hex');
    INSERT INTO voucher_usuarios(nome,email,senha_hash,salt,perfil,permissoes,criado_por)
    VALUES(trim(p_usuario->>'nome'),lower(trim(p_usuario->>'email')),hash,salt,
      COALESCE(NULLIF(p_usuario->>'perfil',''),'usuario'),
      COALESCE((p_usuario->>'permissoes')::jsonb,'[]'::jsonb), s.nome);
  END IF;
  RETURN json_build_object('ok',true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_voucher_salvar_usuario(text,jsonb) TO anon;

CREATE OR REPLACE FUNCTION wc_voucher_toggle_usuario(p_token text, p_id uuid)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE; novo boolean;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil <> 'master' THEN RETURN json_build_object('ok',false,'erro','Sem permissão.'); END IF;
  UPDATE voucher_usuarios SET ativo=NOT ativo WHERE id=p_id RETURNING ativo INTO novo;
  RETURN json_build_object('ok',true,'ativo',novo);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_voucher_toggle_usuario(text,uuid) TO anon;

CREATE OR REPLACE FUNCTION wc_voucher_excluir_usuario(p_token text, p_id uuid)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil <> 'master' THEN RETURN json_build_object('ok',false,'erro','Sem permissão.'); END IF;
  DELETE FROM voucher_usuarios WHERE id=p_id;
  RETURN json_build_object('ok',true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_voucher_excluir_usuario(text,uuid) TO anon;

-- ════════════════════════════════════════════
--  3. CENTRO DE CUSTOS
-- ════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS centro_custos (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  cod         text NOT NULL UNIQUE,  -- gerado automaticamente, editável
  cliente     text NOT NULL DEFAULT 'SPX LOGISTICA LTDA',
  descricao   text,
  ativo       boolean DEFAULT true,
  cep         text,
  logradouro  text,
  numero      text,
  complemento text,
  bairro      text,
  cidade      text,
  uf          text,
  created_by  text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
ALTER TABLE centro_custos DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE centro_custos TO anon;

DROP TRIGGER IF EXISTS trg_cc_upd ON centro_custos;
CREATE TRIGGER trg_cc_upd
  BEFORE UPDATE ON centro_custos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Sequência para gerar COD automático (CC-0001, CC-0002, ...)
CREATE SEQUENCE IF NOT EXISTS seq_centro_custo START 1;

-- Listar centros de custo
CREATE OR REPLACE FUNCTION wc_listar_cc(p_token text)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE; res json;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  SELECT json_agg(c ORDER BY c.cod) INTO res FROM centro_custos c;
  RETURN json_build_object('ok',true,'centros',COALESCE(res,'[]'::json));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_listar_cc(text) TO anon;

-- Salvar centro de custo (Master e Gestor)
CREATE OR REPLACE FUNCTION wc_salvar_cc(p_token text, p_cc jsonb)
RETURNS json AS $$
DECLARE
  s    sessoes%ROWTYPE;
  v_id uuid;
  v_cod text;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil NOT IN ('master','gestor') THEN
    RETURN json_build_object('ok',false,'erro','Apenas Master e Gestores podem gerenciar Centros de Custo.');
  END IF;

  v_id  := NULLIF(trim(p_cc->>'id'),'')::uuid;
  v_cod := NULLIF(trim(p_cc->>'cod'),'');

  IF v_id IS NOT NULL THEN
    -- UPDATE
    IF v_cod IS NOT NULL AND EXISTS(SELECT 1 FROM centro_custos WHERE cod=v_cod AND id<>v_id) THEN
      RETURN json_build_object('ok',false,'erro','Já existe um Centro de Custo com esse código.');
    END IF;
    UPDATE centro_custos SET
      cod         = COALESCE(v_cod, cod),
      cliente     = COALESCE(NULLIF(trim(p_cc->>'cliente'),''), cliente),
      descricao   = p_cc->>'descricao',
      ativo       = COALESCE((p_cc->>'ativo')::boolean, ativo),
      cep         = NULLIF(trim(p_cc->>'cep'),''),
      logradouro  = NULLIF(trim(p_cc->>'logradouro'),''),
      numero      = NULLIF(trim(p_cc->>'numero'),''),
      complemento = NULLIF(trim(p_cc->>'complemento'),''),
      bairro      = NULLIF(trim(p_cc->>'bairro'),''),
      cidade      = NULLIF(trim(p_cc->>'cidade'),''),
      uf          = NULLIF(upper(trim(p_cc->>'uf')),'')
    WHERE id = v_id;
    RETURN json_build_object('ok',true,'id',v_id,'cod',v_cod);
  ELSE
    -- INSERT — gera COD automático se não veio
    IF v_cod IS NULL THEN
      v_cod := 'CC-' || lpad(nextval('seq_centro_custo')::text, 4, '0');
    ELSIF EXISTS(SELECT 1 FROM centro_custos WHERE cod=v_cod) THEN
      RETURN json_build_object('ok',false,'erro','Já existe um Centro de Custo com esse código.');
    END IF;
    INSERT INTO centro_custos(cod,cliente,descricao,ativo,cep,logradouro,numero,complemento,bairro,cidade,uf,created_by)
    VALUES(
      v_cod,
      COALESCE(NULLIF(trim(p_cc->>'cliente'),''),'SPX LOGISTICA LTDA'),
      NULLIF(trim(p_cc->>'descricao'),''),
      COALESCE((p_cc->>'ativo')::boolean,true),
      NULLIF(trim(p_cc->>'cep'),''),
      NULLIF(trim(p_cc->>'logradouro'),''),
      NULLIF(trim(p_cc->>'numero'),''),
      NULLIF(trim(p_cc->>'complemento'),''),
      NULLIF(trim(p_cc->>'bairro'),''),
      NULLIF(trim(p_cc->>'cidade'),''),
      NULLIF(upper(trim(p_cc->>'uf')),''),
      s.nome
    ) RETURNING id INTO v_id;
    RETURN json_build_object('ok',true,'id',v_id,'cod',v_cod);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_salvar_cc(text,jsonb) TO anon;

-- Toggle ativo/inativo
CREATE OR REPLACE FUNCTION wc_toggle_cc(p_token text, p_id uuid)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE; novo boolean;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil NOT IN ('master','gestor') THEN RETURN json_build_object('ok',false,'erro','Sem permissão.'); END IF;
  UPDATE centro_custos SET ativo=NOT ativo WHERE id=p_id RETURNING ativo INTO novo;
  RETURN json_build_object('ok',true,'ativo',novo);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_toggle_cc(text,uuid) TO anon;

-- Excluir
CREATE OR REPLACE FUNCTION wc_excluir_cc(p_token text, p_id uuid)
RETURNS json AS $$
DECLARE s sessoes%ROWTYPE;
BEGIN
  s := _wc_sessao(p_token);
  IF s.token IS NULL THEN RETURN json_build_object('ok',false,'erro','Sessão inválida.','sessaoInvalida',true); END IF;
  IF s.perfil <> 'master' THEN RETURN json_build_object('ok',false,'erro','Apenas o Master pode excluir Centros de Custo.'); END IF;
  DELETE FROM centro_custos WHERE id=p_id;
  RETURN json_build_object('ok',true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION wc_excluir_cc(text,uuid) TO anon;

SELECT 'setup_voucher_cc.sql executado com sucesso!' AS status;
