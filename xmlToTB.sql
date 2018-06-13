USE [Auditor_WHIRLPOOL]
GO
 
-- Criação de tabela temporária
 
IF OBJECT_ID('tempdb..#CARGA_PRESTADORES') IS NOT NULL
BEGIN
    DROP TABLE #CARGA_PRESTADORES
END
 
CREATE TABLE #CARGA_PRESTADORES (
    [CPF] [char](14),
    [NmProfissional] [varchar](50),
    [NmEmpresa] [varchar](50),
    [CNPJ] [char](18),
    [NmCidade] [varchar](40),
    [CdEstado] [char](2),
    [CdInscricaoEstadual] [varchar](20)
)
 
 
-- Carregando os dados a partir do arquivo XML
 
INSERT INTO #CARGA_PRESTADORES
           (CPF
           ,NmProfissional
           ,NmEmpresa
           ,CNPJ
           ,NmCidade
           ,CdEstado
           ,CdInscricaoEstadual)
SELECT
    X.Prestador.query('CPF').value('.', 'CHAR(14)'),
    X.Prestador.query('NomeProfissional').value('.', 'VARCHAR(50)'),
    X.Prestador.query('Empresa').value('.', 'VARCHAR(50)'),
    X.Prestador.query('CNPJ').value('.', 'CHAR(18)'),
    X.Prestador.query('Cidade').value('.', 'VARCHAR(40)'),
    X.Prestador.query('Estado').value('.', 'CHAR(2)'),
    X.Prestador.query('InscricaoEstadual').value('.', 'VARCHAR(20)')
FROM
(   
    SELECT CAST(X AS XML)
    FROM OPENROWSET(
        --BULK 'C:\Users\conrado.moura\Desktop\Prestadores.xml',
        BULK 'E:\Backup_SQL\xml\xml\Prestadores.xml',
        SINGLE_BLOB) AS T(X)
) AS T(X)
CROSS APPLY X.nodes('Prestadores/Prestador') AS X(Prestador);
 
 
-- Incluindo as informações na tabela TB_PRESTADOR
 
DECLARE @CPF CHAR(14)
DECLARE @NmProfissional VARCHAR(50)
DECLARE @NmEmpresa VARCHAR(50)
DECLARE @CNPJ CHAR(18)
DECLARE @NmCidade VARCHAR(40)
DECLARE @CdEstado CHAR(2)
DECLARE @CdInscricaoEstadual VARCHAR(20)
 
DECLARE crPrestadores CURSOR FOR
SELECT CPF
      ,NmProfissional
      ,NmEmpresa
      ,CNPJ
      ,NmCidade
      ,CdEstado
      ,CdInscricaoEstadual
FROM #CARGA_PRESTADORES
ORDER BY CPF
 
OPEN crPrestadores
 
FETCH NEXT FROM crPrestadores INTO
    @CPF, @NmProfissional, @NmEmpresa,
    @CNPJ, @NmCidade, @CdEstado,  @CdInscricaoEstadual
 
BEGIN TRANSACTION -- Inicia uma nova transação
 
WHILE @@FETCH_STATUS = 0
BEGIN
    IF (LTRIM(RTRIM(@CdInscricaoEstadual)) = '')
        SET @CdInscricaoEstadual = NULL
     
    IF (NOT EXISTS(SELECT 1 FROM dbo.TB_PRESTADOR WHERE CPF = @CPF))
    BEGIN
        INSERT INTO dbo.TB_PRESTADOR
                   (CPF
                   ,NmProfissional
                   ,NmEmpresa
                   ,CNPJ
                   ,NmCidade
                   ,CdEstado
                   ,CdInscricaoEstadual)
             VALUES
                   (@CPF
                   ,@NmProfissional
                   ,@NmEmpresa
                   ,@CNPJ
                   ,@NmCidade
                   ,@CdEstado
                   ,@CdInscricaoEstadual)
    END
    ELSE
    BEGIN
        UPDATE dbo.TB_PRESTADOR
           SET CPF = @CPF
              ,NmProfissional = @NmProfissional
              ,NmEmpresa = @NmEmpresa
              ,CNPJ = @CNPJ
              ,NmCidade = @NmCidade
              ,CdEstado = @CdEstado
              ,CdInscricaoEstadual = @CdInscricaoEstadual
        WHERE CPF = @CPF
    END
 
    FETCH NEXT FROM crPrestadores INTO
        @CPF, @NmProfissional, @NmEmpresa,
        @CNPJ, @NmCidade, @CdEstado,  @CdInscricaoEstadual
END
 
CLOSE crPrestadores
 
DEALLOCATE crPrestadores
 
 
-- Verifica a ocorrência de erros e, em caso negativo, confirma
-- a transação iniciada anteriormente
 
IF (@@ERROR = 0)
BEGIN
    COMMIT TRANSACTION
END
ELSE
BEGIN
    ROLLBACK TRANSACTION
END