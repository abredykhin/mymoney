/**
 * @file Defines the queries for the institutions table/view.
 */

const db = require('../');
const log = require('../../utils/logger')('db:institutions');

/**
 * Creates a single item.
 *
 * @param {string} institutionId the Plaid institution ID.
 * @param {string} name name of the institution.
 * @param {string} primaryColor primary color of the institution.
 * @param {string} url url of the institution.
 * @param {string} logo log of the instituion.
 * @returns {Object} the new institution.
 */
const createInstitution = async (
  institutionId,
  name,
  primaryColor,
  url,
  logo
) => {
  log.info(`Storing institution ${institutionId} in db`);
  const query = {
    // RETURNING is a Postgres-specific clause that returns a list of the inserted items.
    text: `
      INSERT INTO institutions_table
        (institution_id, name, primary_color, url, logo)
      VALUES
        ($1, $2, $3, $4, $5)
      ON CONFLICT(institution_id) DO UPDATE SET
        name = EXCLUDED.name,
        primary_color = EXCLUDED.primary_color,
        url = EXCLUDED.url,
        logo = EXCLUDED.logo       
      RETURNING *;
    `,
    values: [institutionId, name, primaryColor, url, logo],
  };
  const { rows } = await db.query(query);
  return rows[0];
};

/**
 * Retrieves a single institution.
 *
 * @param {number} institutionId the ID of the institution.
 * @returns {Object} an institution.
 */
const retrieveInstitutionById = async institutionId => {
  log.info(`Querying db for institution ${institutionId}`);

  const query = {
    text: 'SELECT * FROM institutions WHERE institution_id = $1',
    values: [institutionId],
  };
  const { rows } = await db.query(query);
  // since item IDs are unique, this query will never return more than one row.
  return rows[0];
};

module.exports = {
  createInstitution,
  retrieveInstitutionById,
};
